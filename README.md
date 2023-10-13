![Docker pulls](https://img.shields.io/docker/pulls/benelot/minio-backup-local)
![GitHub actions](https://github.com/benelot/docker-minio-backup-local/actions/workflows/ci.yml/badge.svg?branch=main)

# minio-backup-local

Backup Minio to the local filesystem with periodic rotating backups, based on [prodrigestivill/postgres-backup-s3](https://hub.docker.com/r/prodrigestivill/postgres-backup-local/).
Backup multiple databases from the same host by setting the database names in `MINIO_BUCKET` separated by commas or spaces.

Supports the following Docker architectures: `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/s390x`, `linux/ppc64le`.

Please consider reading detailed the [How the backups folder works?](#how-the-backups-folder-works).

This application requires the docker volume `/backups` to be a POSIX-compliant filesystem to store the backups (mainly with support for hardlinks and softlinks). So filesystems like VFAT, EXFAT, SMB/CIFS, ... can't be used with this docker image.

## Usage

Docker:

```sh
docker run -u minio:minio -v /mnt/data:/data -v /var/opt/backups:/backups -e MINIO_DIR=/data -e MINIO_BUCKET=bucketname benelot/minio-backup-local
```

Docker Compose:

```yaml
version: '2'
services:
    minio:
        image: minio/minio
        restart: always
        command: server /data
        volumes:
            - /mnt/data:/data
    minio-backup:
        image: benelot/minio-backup-local
        restart: always
        volumes:
            - /mnt/data:/data
            - /var/opt/backups:/backups
        links:
            - minio
        depends_on:
            - minio
        environment:
            - MINIO_DIR=/data
            - MINIO_BUCKET=bucketname
            - SCHEDULE=@daily
            - BACKUP_KEEP_DAYS=7
            - BACKUP_KEEP_WEEKS=4
            - BACKUP_KEEP_MONTHS=6
            - HEALTHCHECK_PORT=8080
```

For security reasons it is recommended to run it as user `minio:minio`.

In case of running as `minio` user, the system administrator must initialize the permission of the destination folder as follows:
```sh
# for default images (debian)
mkdir -p /var/opt/backups && chown -R 999:999 /var/opt/backups
# for alpine images
mkdir -p /var/opt/backups && chown -R 70:70 /var/opt/backups
```

### Environment Variables

| env variable | description |
|--|--|
| MINIO_DIR | Directory to save the backup at. Defaults to `/backups`. |
| MINIO_BUCKET | Comma or space separated list of minio buckets to backup. Required. |
| BACKUP_SUFFIX | Filename suffix to save the backup. Defaults to `.sql.gz`. |
| BACKUP_KEEP_DAYS | Number of daily backups to keep before removal. Defaults to `7`. |
| BACKUP_KEEP_WEEKS | Number of weekly backups to keep before removal. Defaults to `4`. |
| BACKUP_KEEP_MONTHS | Number of monthly backups to keep before removal. Defaults to `6`. |
| BACKUP_KEEP_MINS | Number of minutes for `last` folder backups to keep before removal. Defaults to `1440`. |
| HEALTHCHECK_PORT | Port listening for cron-schedule health check. Defaults to `8080`. |
| SCHEDULE | [Cron-schedule](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules) specifying the interval between minio backups. Defaults to `@daily`. |
| TZ | [POSIX TZ variable](https://www.gnu.org/software/libc/manual/html_node/TZ-Variable.html) specifying the timezone used to evaluate SCHEDULE cron (example "Europe/Paris"). |
| WEBHOOK_URL | URL to be called after an error or after a successful backup (POST with a JSON payload, check `hooks/00-webhook` file for more info). Default disabled. |
| WEBHOOK_EXTRA_ARGS | Extra arguments for the `curl` execution in the webhook (check `hooks/00-webhook` file for more info). |


### How the backups folder works?

First a new backup is created in the `last` folder with the full time.

Once this backup finish succefully then, it is hard linked (instead of coping to avoid use more space) to the rest of the folders (daily, weekly and monthly). This step replaces the old backups for that category storing always only the latest for each category (so the monthly backup for a month is always storing the latest for that month and not the first).

So the backup folder are structured as follows:

* `BACKUP_DIR/last/DB-YYYYMMDD-HHmmss.sql.gz`: all the backups are stored separatly in this folder.
* `BACKUP_DIR/daily/DB-YYYYMMDD.sql.gz`: always store (hard link) the **latest** backup of that day.
* `BACKUP_DIR/weekly/DB-YYYYww.sql.gz`: always store (hard link) the **latest** backup of that week (the last day of the week will be Sunday as it uses ISO week numbers).
* `BACKUP_DIR/monthly/DB-YYYYMM.sql.gz`: always store (hard link) the **latest** backup of that month (normally the ~31st).

And the following symlinks are also updated after each successfull backup for simlicity:

```
BACKUP_DIR/last/DB-latest.sql.gz -> BACKUP_DIR/last/DB-YYYYMMDD-HHmmss.sql.gz
BACKUP_DIR/daily/DB-latest.sql.gz -> BACKUP_DIR/daily/DB-YYYYMMDD.sql.gz
BACKUP_DIR/weekly/DB-latest.sql.gz -> BACKUP_DIR/weekly/DB-YYYYww.sql.gz
BACKUP_DIR/monthly/DB-latest.sql.gz -> BACKUP_DIR/monthly/DB-YYYYMM.sql.gz
```

For **cleaning** the script removes the files for each category only if the new backup has been successfull.
To do so it is using the following independent variables:

* BACKUP_KEEP_MINS: will remove files from the `last` folder that are older than its value in minutes after a new successfull backup without affecting the rest of the backups (because they are hard links).
* BACKUP_KEEP_DAYS: will remove files from the `daily` folder that are older than its value in days after a new successfull backup.
* BACKUP_KEEP_WEEKS: will remove files from the `weekly` folder that are older than its value in weeks after a new successfull backup (remember that it starts counting from the end of each week not the beggining).
* BACKUP_KEEP_MONTHS: will remove files from the `monthly` folder that are older than its value in months (of 31 days) after a new successfull backup (remember that it starts counting from the end of each month not the beggining).

### Hooks

The folder `hooks` inside the container can contain hooks/scripts to be run in differrent cases getting the exact situation as a first argument (`error`, `pre-backup` or `post-backup`).

Just create an script in that folder with execution permission so that [run-parts](https://manpages.debian.org/stable/debianutils/run-parts.8.en.html) can execute it on each state change.

Please, as an example take a look in the script already present there that implements the `WEBHOOK_URL` functionality.

### Manual Backups

By default this container makes daily backups, but you can start a manual backup by running `/backup.sh`.

This script as example creates one backup as the running user and saves it the working folder.

```sh
docker run --rm -v "$PWD:/backups" -u "$(id -u):$(id -g)" -e MINIO_DIR=/data -e MINIO_BUCKET=bucketname benelot/minio-backup-local /backup.sh
```

### Automatic Periodic Backups

You can change the `SCHEDULE` environment variable in `-e SCHEDULE="@daily"` to alter the default frequency. Default is `daily`.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

Folders `daily`, `weekly` and `monthly` are created and populated using hard links to save disk space.
