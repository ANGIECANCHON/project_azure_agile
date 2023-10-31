#!/usr/bin/env bash

locust -f locustfile.py --host https://projectazureagile.azurewebsites.net/ --users 100 --spawn-rate 5
