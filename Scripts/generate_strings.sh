#!/bin/bash

genstrings -o ../English.lproj `find -E .. -regex ".*/*.m+" -print`
