#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Apr  6 16:18:22 2020

@author: dlinhardt
"""
import numpy as np
import skimage.transform as skiT
from skimage.transform import resize
from nipy.modalities.fmri.hrf import spm_hrf_compat
import matplotlib.pyplot as plt
from copy import deepcopy
import pickle
from numpy.random import randint

# import traceback
import subprocess
from glob import glob
import os
from scipy.io import loadmat, savemat


class Stimulus:
    def __init__(
        self,
        stimSize=51,
        maxEcc=7,
        TR=2,
        stim_duration=336,
        blank_duration=12,
        loadImages=None,
        flickerFrequency=8,
    ):

        self._maxEcc = maxEcc
        self._stimSize = stimSize
        self.TR = TR
        self._loadImages = loadImages
        self._carrier = "images" if self._loadImages is not None else "checker"

        self.nFrames = int(stim_duration / self.TR)
        self.blankLength = int(blank_duration / self.TR)

        self.flickerFrequency = flickerFrequency  # Hz
        self.nFramesFlicker = int(self.nFrames * np.round(self.TR * self.flickerFrequency + .0001))

    def save(self):
        pass
        """save class as self.name.txt
            not done yet just dummy"""

        file = open(self.name + ".txt", "w")
        file.write(pickle.dumps(self.__dict__))
        file.close()

    def load(self):
        pass
        """try load self.name.txt
            also not done yet"""

        file = open(self.name + ".txt", "r")
        dataPickle = file.read()
        file.close()

        self.__dict__ = pickle.loads(dataPickle)

    def flickeringStim(self):
        """create flickering checkerboard stimulus from binary stimulus mask"""

        if self._stimSize < 512:
            print("You should consider going for higher resolution. e.g. 1024x1024")

        if self._carrier == "checker":
            self._checkerboard()
        elif self._carrier == "images":
            self._loadCarrierImages(self._loadImages)
        else:
            Warning(f"Invalid carrier {self._carrier}, choose from [checker, images]!")

        if not self.continous:
            framesPerPos = int(np.round(self.TR * self.flickerFrequency + .0001))
            self._flickerSeqTimeing = np.arange(
                0, self._stimUnc.shape[0] * self.TR, 1 / self.flickerFrequency
            )
            nF = self.nFrames

        else:
            framesPerPos = 2
            self._flickerSeqTimeing = np.arange(0, self._stimUnc.shape[0], 1 / 2)
            nF = self.nContinousFrames

        self._flickerUncStim = np.ones((self._stimSize, self._stimSize, nF * 2)) * 128
        self._flickerSeq = np.zeros(self.nFramesFlicker, dtype="int")

        if self._carrier == "checker":
            for i in range(nF):
                if self._stimBase[i] == 1:
                    checkOne = self.checkA
                    checkTwo = self.checkB
                elif self._stimBase[i] == 2:
                    checkOne = self.checkC
                    checkTwo = self.checkD

                self._flickerUncStim[..., 2 * i][
                    self._stimUnc[i, ...].astype("bool")
                ] = checkOne[self._stimUnc[i, ...].astype("bool")]
                self._flickerUncStim[..., 2 * i + 1][
                    self._stimUnc[i, ...].astype("bool")
                ] = checkTwo[self._stimUnc[i, ...].astype("bool")]

        elif self._carrier == "images":
            for i in range(nF):
                for j in range(framesPerPos):
                    self._flickerUncStim[..., 2 * i + j][
                        self._stimUnc[i, ...].astype("bool")
                    ] = self.carrierImages[
                        self._stimUnc[i, ...].astype("bool"),
                        randint(self.carrierImages.shape[-1]),
                    ]

        for i in range(nF):
            for j in range(framesPerPos):
                self._flickerSeq[i * framesPerPos + j] = 2 * i + np.mod(j, 2)

    def saveMrVistaStimulus(self, oName, triggerKey="6"):
        """save the created stimulus as mrVista _images and _params to present it at the scanner"""

        if not hasattr(self, "_flickerSeq"):
            self.flickeringStim()

        self.fixSeq = np.zeros(len(self._flickerSeq))
        chunckSize = 9
        colour = 1 if np.random.rand() > 0.5 else 2
        i = 0
        while i < len(self._flickerSeq):
            self.fixSeq[i : i + chunckSize] = colour
            if self.fixSeq[i - 1] != self.fixSeq[i]:
                self.fixSeq[i : i + 4 * chunckSize] = colour
                i += 4 * chunckSize
            else:
                if np.random.rand() < 0.35:
                    colour = 1 if colour == 2 else 2
                i += chunckSize

        oStim = {
            'images'    : self.flickerUncStim.astype("uint8"),
            'seq'       : (self._flickerSeq + 1).astype("uint16"),
            'seqtiming' : self._flickerSeqTimeing.astype('<f8'),
            'cmap'      : np.vstack((aa := np.linspace(0, 1, 256), aa, aa)).T,
            'fixSeq'    : self.fixSeq.astype("uint8"),
        }

        oPara = {
            'experiment' : 'experiment from file',
            'fixation'   : 'disk',
            'modality'   : 'fMRI',
            'trigger'    : 'scanner triggers computer',
            'period'     : np.float64((self.nFrames - self.blankLength * self.crossings / 2) * self.TR),
            'tempFreq'   : np.float64(self.flickerFrequency),
            'tr'         : np.float64(self.TR),
            'scanDuration': np.float64((self.nFrames - self.blankLength * self.crossings / 2) * self.TR),
            'saveMatrix' : 'None',
            'interleaves': [],
            'numImages'  : np.float64(self.nFrames),
            'stimSize'   : 'max',
            'radius'     : np.float64(self._maxEcc),
            'prescanDuration' : np.float64(0),
            'runPriority': np.float64(7),
            'calibration': [],
            'numCycles'  : np.float64(1),
            'repetitions': np.float64(1),
            'motionSteps': np.float64(2),
            'countdown'  : np.float64(0),
            'startScan'  : np.float64(0),
        }

        oMat  = {
            'stimulus' : oStim,
            'params'   : oPara,
        }

        # if "/" not in oName:
        # savemat(os.path.join("/home_local/dlinhardt/Dropbox/measurementlaptop/images", oName), oMat)
        # else:
        print(f"Saving {oName}... ")
        savemat(oName, oMat, do_compression=True)
        print(f"saved.")

    def playVid(self, z=None, flicker=False):
        """play the stimulus video, if not defined otherwise, the unconvolved stimulus"""

        if flicker:
            if not hasattr(self, "_flickerSeq"):
                self.flickeringStim()

            plt.figure(constrained_layout=True)
            plt.gca().set_aspect("equal", "box")
            for i in range(len(self._flickerSeq)):
                plt.title(i)
                if i == 0:
                    img_artist = plt.gca().imshow(
                        self.flickerUncStim[..., self._flickerSeq[i]],
                        cmap="Greys",
                        vmin=0,
                        vmax=255,
                    )
                else:
                    img_artist.set_data(self.flickerUncStim[..., self._flickerSeq[i]])
                plt.pause(1 / self.flickerFrequency)
        else:
            if not np.any(z):
                z = self._stimUnc
            plt.figure()

            for i in range(z.shape[0]):
                plt.title(i)
                if i == 0:
                    img_artist = plt.gca().imshow(z[i, ...], cmap="Greys")
                else:
                    img_artist.set_data(z[i, ...])
                plt.pause(0.1)

    def saveVid(self, vPath, vName, z=None):
        """save the stimulus video to given path, if not defined otherwise, the unconvolved stimulus"""
        if not np.any(z):
            z = self._stimUnc
        for i in range(self.nFrames):
            plt.title(i)
            plt.imshow(z[i, ...])
            plt.savefig(vPath + "/file%02d_frame.png" % i, dpi=150)

        subprocess.call(
            [
                "ffmpeg",
                "-framerate",
                "2",
                "-i",
                vPath + "/file%02d_frame.png",
                "-r",
                "30",
                "-pix_fmt",
                "yuv420p",
                vPath + "/" + vName + ".mp4",
            ]
        )
        for file_name in glob(vPath + "/*_frame.png"):
            os.remove(file_name)

    def _cart2pol(self, x, y):
        rho = np.sqrt(x ** 2 + y ** 2)
        phi = np.arctan2(y, x)
        return rho, phi

    def _pol2cart(self, rho, phi):
        x = rho * np.cos(phi)
        y = rho * np.sin(phi)
        return x, y

    def _create_mask(self, shape):
        x0, y0 = shape[1] // 2, shape[1] // 2
        n = shape[1]
        r = shape[1] // 2

        y, x = np.ogrid[-x0 : n - x0, -y0 : n - y0]
        self._stimMask = x * x + y * y <= r * r

    @property
    def xVec(self):
        if not hasattr(self, "x"):
            self.y, self.x = np.meshgrid(
                np.linspace(-self._maxEcc, self._maxEcc, self._stimSize),
                np.linspace(-self._maxEcc, self._maxEcc, self._stimSize),
            )
        return self.x[self._stimMask]

    @property
    def yVec(self):
        if not hasattr(self, "y"):
            self.y, self.x = np.meshgrid(
                np.linspace(-self._maxEcc, self._maxEcc, self._stimSize),
                np.linspace(-self._maxEcc, self._maxEcc, self._stimSize),
            )
        return self.y[self._stimMask]

    @property
    def stimUncOrigVec(self):
        return self._stimUncOrig[:, self._stimMask].T

    @property
    def stimOrigVec(self):
        return self._stimOrig[:, self._stimMask].T

    @property
    def stimUncVec(self):
        if not hasattr(self, "_stim"):
            self.convHRF()
        return self._stimUnc[:, self._stimMask].T

    @property
    def flickerUncStim(self):
        if not hasattr(self, "_flickerUncStim"):
            self.flickeringStim()
        return self._flickerUncStim

    @property
    def stim(self):
        if not hasattr(self, "_stim"):
            self.convHRF()
        return self._stim

    @property
    def stimUnc(self):
        return self._stimUnc

    @property
    def stimVec(self):
        if not hasattr(self, "_stim"):
            self.convHRF()
        return self._stim[:, self._stimMask].T

    # things we need for every analysis

    def convHRF(self):
        """'Convolve stimUnc with SPM HRF"""
        self.hrf = spm_hrf_compat(np.linspace(0, 30, 15 + 1))

        self._stim = np.apply_along_axis(
            lambda m: np.convolve(m, self.hrf, mode="full")[:],
            axis=0,
            arr=self._stimUnc,
        )
        self._stim = self._stim[: self._stimUnc.shape[0], ...]

        if hasattr(self, "_stimUncOrig"):
            self._stimOrig = np.apply_along_axis(
                lambda m: np.convolve(m, self.hrf, mode="full")[:],
                axis=0,
                arr=self._stimUncOrig,
            )
            self._stimOrig = self._stimOrig[: self._stimUncOrig.shape[0], ...]

    # different artificial scotomas

    def centralScotoma(self, scotSize):
        """Mask stimulus with central round scotoma"""

        self._stimUncOrig = deepcopy(self._stimUnc)

        mask = np.ones((self._stimSize, self._stimSize))

        x0, y0 = self._stimSize // 2, self._stimSize // 2
        n = self._stimSize
        r = self._stimSize // 2 * scotSize // self._maxEcc

        y, x = np.ogrid[-x0 : n - x0, -y0 : n - y0]
        mask = x * x + y * y >= r * r

        self._stimUnc *= mask[None, ...]

    def peripheralScotoma(self, scotSize):
        """Mask stimulus with peripheral part missing"""

        self._stimUncOrig = deepcopy(self._stimUnc)

        mask = np.ones((self._stimSize, self._stimSize))

        x0, y0 = self._stimSize // 2, self._stimSize // 2
        n = self._stimSize
        r = self._stimSize // 2 * scotSize // self._maxEcc

        y, x = np.ogrid[-x0 : n - x0, -y0 : n - y0]
        mask = x * x + y * y <= r * r

        self._stimUnc *= mask[None, ...]

    def quaterout(self):
        """Mask stimulus with one quater missing all the time"""

        self._stimUncOrig = deepcopy(self._stimUnc)

        mask = np.ones((self._stimSize, self._stimSize))

        for i in range(self._stimSize):
            for j in range(self._stimSize):
                mask[i, j] = (
                    0
                    if np.all((i > self._stimSize // 2, j > self._stimSize // 2))
                    else 1
                )

        self._stimUnc *= mask[None, ...]

    def verification(self):
        """Mask stimulus so that Quadrants:
        IV:  2 stimulations
        III: 4 stimulations
        II:  6 stimulations
        I:   8 stimulations
        """
        self._stimUncOrig = deepcopy(self._stimUnc)

        maskQ1 = np.ones((self._stimSize, self._stimSize))
        maskQ2 = np.ones((self._stimSize, self._stimSize))
        maskQ3 = np.ones((self._stimSize, self._stimSize))

        for i in range(self._stimSize):
            for j in range(self._stimSize):
                maskQ1[i, j] = (
                    0
                    if np.all((i > self._stimSize // 2, j > self._stimSize // 2))
                    else 1
                )
                maskQ2[i, j] = 0 if i > self._stimSize // 2 else 1
                maskQ3[i, j] = (
                    0
                    if np.any((j < self._stimSize // 2, i > self._stimSize // 2))
                    else 1
                )

        # 0-18, 18-36, 42-60, 60-78, 84-102, 102-120, 126-144, 144-162

        for i in range(int(self.nFrames)):
            if i >= 0 and i < self.framesPerCrossing:
                pass
            elif i >= self.framesPerCrossing and i < self.framesPerCrossing * 2:
                self._stimUnc[i, ...] *= maskQ1
            elif (
                i >= self.framesPerCrossing * 2 + self.blankLength and
                i < self.framesPerCrossing * 3 + self.blankLength
            ):
                self._stimUnc[i, ...] *= maskQ2
            elif (
                i >= self.framesPerCrossing * 3 + self.blankLength and
                i < self.framesPerCrossing * 4 + self.blankLength
            ):
                self._stimUnc[i, ...] *= maskQ3
            elif (
                i >= self.framesPerCrossing * 4 + self.blankLength * 2 and
                i < self.framesPerCrossing * 5 + self.blankLength * 2
            ):
                pass
            elif (
                i >= self.framesPerCrossing * 5 + self.blankLength * 2 and
                i < self.framesPerCrossing * 6 + self.blankLength * 2
            ):
                self._stimUnc[i, ...] *= maskQ1
            elif (
                i >= self.framesPerCrossing * 6 + self.blankLength * 3 and
                i < self.framesPerCrossing * 7 + self.blankLength * 3
            ):
                self._stimUnc[i, ...] *= maskQ2
            elif (
                i >= self.framesPerCrossing * 7 + self.blankLength * 3 and
                i < self.framesPerCrossing * 8 + self.blankLength * 3
            ):
                self._stimUnc[i, ...] *= maskQ3

    def _loadCarrierImages(self, loadImages):
        if loadImages.endswith(".mat"):
            self.carrierImages = loadmat(loadImages, simplify_cells=True)["images"][
                :, :, 1, :
            ]

            # resize them if necessary
            if (
                self.carrierImages.shape[0] != self._stimSize or
                self.carrierImages.shape[1] != self._stimSize
            ):
                self.carrierImages = resize(
                    self.carrierImages,
                    (self._stimSize, self._stimSize),
                    anti_aliasing=True,
                )

            # rescale them to [0,255]
            if self.carrierImages.min() != 0:
                self.carrierImages += self.carrierImages.min()

            if self.carrierImages.max() != 255:
                if self.carrierImages.max() != 1:
                    self.carrierImages %= self.carrierImages.max()
                self.carrierImages *= 255
                self.carrierImages = self.carrierImages.astype(int)

        else:
            Warning("Please provide carrier images as .mat file!")


# %%
class barStimulus(Stimulus):
    """Define a Stimulus of eight bars crossing though the FoV from different dicetions"""

    def __init__(
        self,
        stimSize=101,
        maxEcc=7,
        overlap=1 / 2,
        nBars=1,
        doubleBarRot=0,
        thickRatio=1,
        continous=False,
        TR=2,
        stim_duration=336,
        blank_duration=12,
        loadImages=None,
        flickerFrequency=8,
        forceBarWidth=None,
    ):

        super().__init__(
            stimSize,
            maxEcc,
            TR=TR,
            stim_duration=stim_duration,
            blank_duration=blank_duration,
            loadImages=loadImages,
            flickerFrequency=flickerFrequency,
        )

        self.continous = continous

        self.nBars = nBars
        self.doubleBarRot = doubleBarRot
        self.thickRatio = thickRatio

        self.forceBarWidth = forceBarWidth

        self.startingDirection = [0, 3, 6, 1, 4, 7, 2, 5]
        self.crossings = len(self.startingDirection)

        self.framesPerCrossing = int(
            (self.nFrames - 4 * self.blankLength) / self.crossings
        )

        if self.forceBarWidth is not None:
            forceBarWidthPix = np.ceil(self.forceBarWidth / (2 * self._maxEcc) * self._stimSize).astype('int')
            self.barWidth = forceBarWidthPix
            self.overlap  = (self._stimSize + 0.5) / (self.barWidth * self.framesPerCrossing)
        else:
            self.overlap  = overlap
            self.barWidth = np.ceil(self._stimSize / (self.framesPerCrossing * self.overlap - 0.5)).astype('int')

        if not continous:
            self._stimRaw = np.zeros((self.nFrames, self._stimSize, self._stimSize))
            self._stimBase = np.zeros(self.nFrames)  # to find which checkerboard to use

            it = 0
            for cross in self.startingDirection:
                for i in range(self.framesPerCrossing):
                    frame = np.zeros((self._stimSize, self._stimSize))
                    frame[
                        :,
                        max(0, int(self.overlap * self.barWidth * (i - 1))) : min(
                            self._stimSize,
                            int(
                                self.overlap * self.barWidth * (i - 1) +
                                self.barWidth
                            ),
                        ),
                    ] = 1

                    if self.nBars > 1:
                        self.nBarShift = self._stimSize // self.nBars
                        frame2 = np.zeros((self._stimSize, self._stimSize))
                        frame3 = np.zeros((self._stimSize, self._stimSize))

                        for nbar in range(self.nBars - 1):
                            if i == 0:
                                o = max(
                                    int(np.ceil(self._stimSize / 2 - 1)),
                                    int(
                                        self.overlap * self.barWidth * (i - 1) +
                                        self.barWidth * self.thickRatio * 0.55 +
                                        self.nBarShift * (nbar + 1)
                                    ),
                                )
                                t = int(
                                    self.overlap * self.barWidth * (i - 1) +
                                    self.barWidth * self.thickRatio +
                                    self.nBarShift * (nbar + 1)
                                )
                            elif i == self.framesPerCrossing - 1:
                                o = int(
                                    self.overlap * self.barWidth * (i - 1) +
                                    self.nBarShift * (nbar + 1)
                                )
                                t = int(
                                    self.overlap * self.barWidth * (i - 1) +
                                    self.barWidth * self.thickRatio * 0.45 +
                                    self.nBarShift * (nbar + 1)
                                )
                            else:
                                o = int(
                                    self.overlap * self.barWidth * (i - 1) +
                                    self.nBarShift * (nbar + 1)
                                )
                                t = int(
                                    self.overlap * self.barWidth * (i - 1) +
                                    self.barWidth * self.thickRatio +
                                    self.nBarShift * (nbar + 1)
                                )

                            frame2[:, max(0, o) : min(self._stimSize, t)] = 1
                            frame3[
                                :,
                                max(0, o - self._stimSize) : max(
                                    0,
                                    min(
                                        int(np.floor(self._stimSize / 2)),
                                        min(self._stimSize, t - self._stimSize),
                                    ),
                                ),
                            ] = 1

                            frame2 = skiT.rotate(frame2, self.doubleBarRot, order=0)
                            frame3 = skiT.rotate(frame3, self.doubleBarRot, order=0)
                            frame = np.any(np.stack((frame, frame2, frame3), 2), 2)

                    self._stimRaw[it, ...] = skiT.rotate(
                        frame, cross * 360 / self.crossings, order=0
                    )

                    self._stimBase[it] = np.mod(cross, 2) + 1

                    it += 1

                if cross % 2 != 0:
                    it += self.blankLength

            self._create_mask(self._stimRaw.shape)

            self._stimUnc = np.zeros(self._stimRaw.shape)
            self._stimUnc[:, self._stimMask] = self._stimRaw[:, self._stimMask]

        else:
            self.frameMultiplier = self.TR * self.flickerFrequency / 2
            self.nContinousFrames = int(self.nFrames * self.frameMultiplier)
            self.continousBlankLength = int(self.blankLength * self.frameMultiplier)
            self.framesPerCrossing = int(
                (self.nContinousFrames - 4 * self.continousBlankLength) / self.crossings
            )

            self._stimRaw = np.zeros(
                (self.nContinousFrames, self._stimSize, self._stimSize)
            )
            self._stimBase = np.zeros(
                self.nContinousFrames
            )  # to find which checkerboard to use

            it = 0
            for cross in self.startingDirection:
                for i in range(self.framesPerCrossing):
                    frame = np.zeros((self._stimSize, self._stimSize))
                    frame[
                        :,
                        max(
                            0,
                            int(
                                self.overlap *
                                self.barWidth /
                                self.frameMultiplier *
                                (i - self.frameMultiplier * 2)
                            ),
                        ) : min(
                            self._stimSize,
                            int(
                                self.overlap *
                                self.barWidth /
                                self.frameMultiplier *
                                (i - self.frameMultiplier * 2) +
                                self.barWidth
                            ),
                        ),
                    ] = 1

                    # if self.nBars > 1:
                    #     self.nBarShift = self._stimSize // self.nBars
                    #     frame2 = np.zeros((self._stimSize,self._stimSize))

                    #     for nbar in range(self.nBars-1) :
                    #         o = int(self.overlap*self.barWidth*(i-1)                                     + self.nBarShift*(nbar+1))
                    #         t = int(self.overlap*self.barWidth*(i-1) + self.barWidth*self.thickRatio + self.nBarShift*(nbar+1))
                    #         if o>self._stimSize: o -= self._stimSize
                    #         if t>self._stimSize: t -= self._stimSize
                    #         frame2[:, max(0, o):min(self._stimSize, t)] = 1
                    #         frame2 = skiT.rotate(frame2, self.doubleBarRot, order=0)
                    #         frame = np.any(np.stack((frame,frame2), 2), 2)

                    self._stimRaw[it, ...] = skiT.rotate(
                        frame, cross * 360 / self.crossings, order=0
                    )

                    self._stimBase[it] = np.mod(cross, 2) + 1

                    it += 1

                if cross % 2 != 0:
                    it += self.continousBlankLength

            self._create_mask(self._stimRaw.shape)

            self._stimUnc = np.zeros(self._stimRaw.shape)
            self._stimUnc[:, self._stimMask] = self._stimRaw[:, self._stimMask]

    def _checkerboard(self, nChecks=10):
        """create the four flickering main images"""
        self.nChecks = nChecks
        checkSize = np.ceil(self._stimSize / self.nChecks / 2).astype("int")

        self.checkA = np.kron(
            [[0, 255] * (self.nChecks + 1), [255, 0] * (self.nChecks + 1)] *
            (self.nChecks + 1),
            np.ones((checkSize, checkSize)),
        )[
            int(checkSize * 3 / 2) : -int(checkSize / 2),
            int(checkSize / 2) : -int(checkSize * 3 / 2),
        ]
        self.checkB = np.kron(
            [[255, 0] * (self.nChecks + 1), [0, 255] * (self.nChecks + 1)] *
            (self.nChecks + 1),
            np.ones((checkSize, checkSize)),
        )[
            int(checkSize * 3 / 2) : -int(checkSize / 2),
            int(checkSize / 2) : -int(checkSize * 3 / 2),
        ]

        self.checkC = np.where(
            skiT.rotate(
                np.kron(
                    [[0, 255] * (self.nChecks + 1), [255, 0] * (self.nChecks + 1)] *
                    (self.nChecks + 1),
                    np.ones((checkSize, checkSize)),
                ),
                angle=45,
                resize=False,
                order=0,
            ) <
            128,
            0,
            255,
        )[checkSize:-checkSize, checkSize:-checkSize]
        self.checkD = np.where(
            skiT.rotate(
                np.kron(
                    [[255, 0] * (self.nChecks + 1), [0, 255] * (self.nChecks + 1)] *
                    (self.nChecks + 1),
                    np.ones((checkSize, checkSize)),
                ),
                angle=45,
                resize=False,
                order=0,
            ) <
            128,
            0,
            255,
        )[checkSize:-checkSize, checkSize:-checkSize]

        if self.checkA.shape[0] != self._stimSize:
            diff = (self.checkA.shape[0] - self._stimSize) / 2
            self.checkA = self.checkA[
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
            ]
            self.checkB = self.checkB[
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
            ]
        if self.checkC.shape[0] != self._stimSize:
            diff = (self.checkC.shape[0] - self._stimSize) / 2
            self.checkC = self.checkC[
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
            ]
            self.checkD = self.checkD[
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
                np.floor(diff).astype("int") : -np.ceil(diff).astype("int"),
            ]


# %%
class wedgeStimulus(Stimulus):
    """Define a Stimulus of roataing wedge and expanding/contracting rings"""

    def __init__(
        self,
        stimSize=101,
        maxEcc=7,
        overlap=1 / 2,
        TR=2,
        nStims=1,
        stim_duration=336,
        blank_duration=12,
    ):

        super().__init__(
            stimSize,
            maxEcc,
            TR=TR,
            stim_duration=stim_duration,
            blank_duration=blank_duration,
        )

        self.overlap = overlap

        self.framesPerParadigm = 36
        self.wedgeWidth = 2 * np.pi * 2 / self.framesPerParadigm / self.overlap
        # self.ringWidth  =

        self.paradigms = [
            "wCCW",
            "r",
            "wCW",
            "r",
        ]  # 'wedgeCCW', 'ring','wedgeCW', 'ring'
        self._stimBase = np.ones(self.nFrames)

        # define meshgrid in polar corrdinates
        self.X, self.Y = np.meshgrid(
            np.linspace(-self._stimSize // 2, self._stimSize // 2 - 1, self._stimSize) +
            0.5,
            np.linspace(-self._stimSize // 2, self._stimSize // 2 - 1, self._stimSize) +
            0.5,
        )
        self.R, self.P = np.sqrt(self.X ** 2 + self.Y ** 2), np.arctan2(self.Y, self.X)
        self.P[self.P < 0] += 2 * np.pi

        it = 0
        for cross in self.paradigms:
            for i in range(self.framesPerParadigm):
                frame = np.zeros((self._stimSize, self._stimSize))

                if "w" in cross:
                    pass
                    # minP =
                    # maxP =
                    # frame[np.all((self.P>minP, self.P<maxP),0)] = 1

                elif "r" in cross:
                    pass
                    # minR =
                    # maxR =
                    # frame[np.all((self.R>minR, self.R<maxR),0)] = 1

                self._stimRaw[it, ...] = frame
                it += 1

            it += self.blankLength

        # self.nBars = nBars
        # self.doubleBarRot = doubleBarRot
        # self.thickRatio = thickRatio

        # self.startingDirection = [0,3,6,1,4,7,2,5]
        # self.crossings = len(self.startingDirection)
        # self.framesPerCrossing = 18

        # self.overlap = overlap
        # self.barWidth = np.ceil(self._stimSize / (self.framesPerCrossing * self.overlap - .5)).astype('int')

        # self._stimRaw = np.zeros((self.nFrames, self._stimSize, self._stimSize))
        # self._stimBase = np.zeros(self.nFrames) # to find which checkerboard to use

        # it = 0
        # for cross in self.startingDirection:
        #     for i in range(self.framesPerCrossing):
        #         frame = np.zeros((self._stimSize,self._stimSize))
        #         frame[:, max(0, int(self.overlap*self.barWidth*(i-1))):min(self._stimSize, int(self.overlap*self.barWidth*(i-1)+self.barWidth))] = 1

        #         if self.nBars > 1:
        #             self.nBarShift = self._stimSize // self.nBars
        #             frame2 = np.zeros((self._stimSize,self._stimSize))

        #             for nbar in range(self.nBars-1) :
        #                 o = int(self.overlap*self.barWidth*(i-1)                                     + self.nBarShift*(nbar+1))
        #                 t = int(self.overlap*self.barWidth*(i-1) + self.barWidth*self.thickRatio + self.nBarShift*(nbar+1))
        #                 if o>self._stimSize: o -= self._stimSize
        #                 if t>self._stimSize: t -= self._stimSize
        #                 frame2[:, max(0, o):min(self._stimSize, t)] = 1
        #                 frame2 = skiT.rotate(frame2, self.doubleBarRot, order=0)
        #                 frame = np.any(np.stack((frame,frame2), 2), 2)

        #         self._stimRaw[it,...] = skiT.rotate(frame, cross*360/self.crossings, order=0)

        #         self._stimBase[it] = np.mod(cross,2)+1

        #         it += 1

        #     if cross%2 != 0:
        #         it += self.blankLength

        # self._create_mask(self._stimRaw.shape)

        # self._stimUnc = np.zeros(self._stimRaw.shape)
        # self._stimUnc[:,self._stimMask] = self._stimRaw[:,self._stimMask]

    def _checkerboard(self):
        """create the two flickering main images"""
        self.nFlickerRings = 18
        self.nFlickerWedge = 24

        flickerRingsWidth = self._stimSize / (self.nFlickerRings) / 2
        flickerWedgeWidth = 2 * np.pi / self.nFlickerWedge

        self.checkA = np.ones((self._stimSize, self._stimSize))
        self.checkB = np.ones((self._stimSize, self._stimSize))

        for ring in range(self.nFlickerRings):
            for wedge in range(self.nFlickerWedge):
                msk = np.all(
                    (
                        R > flickerRingsWidth * ring,
                        R < flickerRingsWidth * (ring + 1),
                        P > flickerWedgeWidth * wedge,
                        P < flickerWedgeWidth * (wedge + 1),
                    ),
                    0,
                )

                self.checkA[msk] = np.mod(ring + wedge, 2)
                self.checkB[msk] = np.mod(ring + wedge + 1, 2)
