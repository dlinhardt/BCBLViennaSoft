"""
Create stimulus
===============
This are the instrucctions from David's email
from stimulus import barStimulus
stim = barStimulus(stimSize=1024, maxEcc=9, overlap=1/3, TR=.8, stim_duration=300, blank_duration=10, flickerFrequency=2.5, loadImages='/local/dlinhardt/develop/bcbl_stims/test_images.mat')
"stim.saveMrVistaStimulus('/local/dlinhardt/develop/bcbl_stims/words_tr-0.8_duration-300s.mat', triggerKey='s')

Maybe you have to change the \"_loadCarrierImages\" functions to read in the files correctly!
and also the params for your scanner in \"saveMrVistaStimulus\

I will do the distance measurements next week when the scanner is free.\n",

The call for the checkers:\n",

from stimulus import barStimulus
stim = barStimulus(stimSize=1024, maxEcc=9, overlap=1/3, TR=.8, stim_duration=300, blank_duration=10, flickerFrequency=2.5)
stim.saveMrVistaStimulus('/local/dlinhardt/develop/bcbl_stims/checkers_tr-0.8_duration-300s.mat', triggerKey='s')
"""

from pythoncode.stimulus import barStimulus
import os

join = os.path.join

# Find root path of the repo in any computer
try:
    RP = globals()['_dh'][0].parent
except:
    RP = os.path.dirname(os.path.realpath(__file__)).parent


triggerKey = "generic"  # 
localpath = join(RP, "images")
stimSize  = 1024
maxEccs   = [8, 9] # 9 Vienna, 8 BCBL until changes
overlap   = 1 / 3

duration = 300
blank_duration = 10
forceBarWidth  = 2
trs_flickerFreqs = [(0.8, 2.5), (1, 2)] # [(0.8, 2.5), (1, 2)]

# langs = ["ES","AT"]
# imnames = ["CB", "PW", "FF", "RW", "PW10", "PW20", "FF10", "FF20", "RW10", "RW20"]
langs = ["AT"]
imnames = ["CB", "RW"]

for (tr, flickerFrequency) in trs_flickerFreqs:
    for lang in langs:
        for imname in imnames:
            for maxEcc in maxEccs:
                imfilename = f"{lang}_{imname}_{stimSize}x{stimSize}x100.mat"
                loadImages = join(RP, "morphing", "DATA", "retWordsMagno", imfilename)
                if imname == "CB":
                    stim = barStimulus(
                                        stimSize=stimSize,
                                        maxEcc=maxEcc,
                                        overlap=overlap,
                                        TR=tr,
                                        stim_duration=duration,
                                        blank_duration=blank_duration,
                                        flickerFrequency=flickerFrequency,
                                        forceBarWidth=forceBarWidth,
                                    )
                else:
                    stim = barStimulus(
                                        stimSize=stimSize,
                                        maxEcc=maxEcc,
                                        overlap=overlap,
                                        TR=tr,
                                        stim_duration=duration,
                                        blank_duration=blank_duration,
                                        flickerFrequency=flickerFrequency,
                                        loadImages=loadImages,                    
                                        forceBarWidth=forceBarWidth,
                                    )
                oName = f"{lang}_{imname}_tr-{tr}_duration-{duration}sec" \
                        f"_size-{stimSize}pix_" \
                        f"maxEcc-{maxEcc}deg_barWidth-{forceBarWidth}deg.mat"
                oPath = join(localpath, oName)
                stim.saveMrVistaStimulus(oPath, triggerKey=triggerKey)
                