#!/bin/sh
# This is used to monitor changes to the content dir and automatically mirror them in production.

find content | entr -a didact-template /_
