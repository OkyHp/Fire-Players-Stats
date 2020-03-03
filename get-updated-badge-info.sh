#!/bin/bash

echo "collecting stas for badges"

commits=`git rev-list --all --count`
latest_release_tag=`git describe --abbrev=0`
echo "{\"commits\":\"$commits\", \"release_tag"\:\"$latest_release_tag\"}" > badges.json