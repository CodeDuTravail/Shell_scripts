# Shell_scripts

A collection of shell scripts for various purposes.

* 1st_run_you_only_launch_once.sh
    >A script for first run on a fresh build server
    - Set Hostname
    - Configure IP static, DNS servers
    - SSH Port modification
    - User creation
    - Packages install

* ssh_key_n_config.sh
    ```bash
    Usage: ./ssh_key_n_config.sh user@server:port
    ```
    >What do this script ?
    - Generate a ed25519 SSH Key
    - Configure an entry for the user@host:port in ~/.ssh/config
    - Copy ssh key with ssh-copy-id to the target host

* cert_expiration.sh
    >A simple script to check SSL certificate expiration date and send an alert mail 7 days before it expire. 


* rsync_a_lot.sh
    ```bash
    Usage: ./rsync_a_lot.sh <input_file> [rsync_options]
    ```
    >A Batch rsync script to copy multiples folders with a file list.
    Input file format: Each line should contain: "source_path;target_path"


* ufw_set_n_check.sh
    - Check ports in use to configure UFW allow rules.
    - Create a conf file and crontab task to check if new ports are in use and send an mail alert.