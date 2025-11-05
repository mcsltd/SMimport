## About SMimport
SMimport is the EEGLAB plugin to import EEG from an SM file format data.
EEGLAB is an open source EEG analysis software built on the MATLAB platform. It can be
downloaded from the developer’s website at http://sccn.ucsd.edu/eeglab/. 
Medical Computer System does not take responsibility for the function of EEGLAB.

SM file format data contains EEG signals. It's used by devices of Neorec and NVX series,
produced by MCS company (https://mks.ru).

## License
MIT License
Copyright (c) 2025 Medical Computer Systems Ltd

## Requirements
This plugin expect MATLAB version 2019 or higher and EEGLAB version 2024.0 or higher.
Also, older versions may work.

## Installation
To install the EEGLAB plug-in, copy the plug-in folder `SMimport1.2` into your
EEGLAB plug-ins folder. Restart MATLAB, if it was running during the installation.

## Usage
After installation, you can see a new menu item in the EEGLAB menu bar:
```File -> Import data -> Using EEGLAB functions and plugins -> From MCS .SM file```

## Version history
v. 1.0 + First Release
v. 1.1 + Errors fixed and experemental decoding #1 method support added
v. 1.2 + Enhanced support for complicated SM records and error fixed

