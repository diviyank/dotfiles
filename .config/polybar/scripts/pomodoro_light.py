#!/usr/bin/env python

import sys
import dbus
from time import time, sleep
import signal
import os
import pathlib

print(os.getpid(), flush=True)
# sleep(3)
global reset 
reset = False

def fix_string(string):
    # corrects encoding for the python version used
    if sys.version_info.major == 3:
        return string
    else:
        return string.encode('utf-8')

# Default parameters
output = fix_string(u'{play_pause} {min}:{seconds}')
trunclen = 35
play_pause = fix_string(u'%{F#ea2121}\uf04b,%{F#f78138}\uf04c') # first character is play, second is paused
play_pause = play_pause.split(',')

label_with_font = '%{{T{font}}}{label}%{{T-}}'
pomodoro_ratio = [20, 5]

pomodoro_ratio_seconds = [i*60 for i in pomodoro_ratio]
pomodoro_total = sum(pomodoro_ratio_seconds)
quiet = False

def signal_handler(sig, frame):
    global reset
    reset = True
    return

signal.signal(signal.SIGUSR1, signal_handler)

# while True:
try:
    real_time = int(time())
    offset = int(pathlib.Path(
        '/home/diviyan/.config/polybar/scripts/pomodoro_offset.txt'
    ).read_text())
    current_time = (real_time + offset) % pomodoro_total

    if reset:
        if current_time < pomodoro_ratio_seconds[0]:
            offset = (offset + (pomodoro_ratio_seconds[0] - current_time)) % pomodoro_total
            current_time = pomodoro_ratio_seconds[0]
        else:
            offset = ( offset + (pomodoro_total - current_time)) % pomodoro_total
            current_time = 0
        with open('/home/diviyan/.config/polybar/scripts/pomodoro_offset.txt', 'w') as f:
            f.write(str(offset))
        reset = False

    # Handle play/pause label
    if current_time < pomodoro_ratio_seconds[0]:
        status = "Playing"
        minutes = current_time // 60
        seconds = current_time % 60
    else:
        status = "Paused"
        minutes = (current_time - pomodoro_ratio_seconds[0]) // 60
        seconds = (current_time - pomodoro_ratio_seconds[0]) % 60

    if status == 'Playing':
        play_pause_it = play_pause[0]
    elif status == 'Paused':
        play_pause_it = play_pause[1]
    else:
        play_pause_it = str()

    print(f"{play_pause_it}  {minutes}:{seconds:02d}", flush=True)
#         sleep(1)
    current_time += 1
except Exception as e:
    if isinstance(e, dbus.exceptions.DBusException):
        print('')
    else:
        print(e)
        raise e
