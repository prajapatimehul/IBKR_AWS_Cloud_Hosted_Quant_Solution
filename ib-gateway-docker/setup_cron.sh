#!/bin/bash

# Install cron
apt-get update && apt-get install -y cron

# Create a cron job file
echo "56 15 * * * /usr/local/bin/python /home/jovyan/work/daily_balance_check.py >> /home/jovyan/work/cron.log 2>&1" > /etc/cron.d/balance_check

# Give execution rights on the cron job
chmod 0644 /etc/cron.d/balance_check

# Apply cron job
crontab /etc/cron.d/balance_check

# Create the log file
touch /home/jovyan/work/cron.log

# Start cron
service cron start

