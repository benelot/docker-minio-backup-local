#!/usr/bin/env bash
set -Eeo pipefail

HOOKS_DIR="/hooks"
if [ -d "${HOOKS_DIR}" ]; then
  on_error(){
    run-parts -a "error" "${HOOKS_DIR}"
  }
  trap 'on_error' ERR
fi

if [ "${MINIO_BUCKET}" = "**None**" ]; then
  echo "You need to set the MINIO_BUCKET environment variable."
  exit 1
fi

if [ "${MINIO_DIR}" = "**None**" ]; then
  echo "You need to set the MINIO_DIR environment variable."
  exit 1
fi

KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

#Initialize dirs
mkdir -p "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Loop all buckets
for BUCKET in ${MINIO_BUCKET}; do
  #Initialize filename vers
  LAST_FILENAME="${BUCKET}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
  DAILY_FILENAME="${BUCKET}-`date +%Y%m%d`${BACKUP_SUFFIX}"
  WEEKLY_FILENAME="${BUCKET}-`date +%G%V`${BACKUP_SUFFIX}"
  MONTHY_FILENAME="${BUCKET}-`date +%Y%m`${BACKUP_SUFFIX}"
  FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
  DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
  WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
  MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"

  #Create dump
  echo "Creating dump of Minio ${BUCKET} bucket..."
  cd "$MINIO_DIR"
  tar -cvzf "$FILE" $BUCKET
  cd -
  
  #Copy (hardlink) for each entry
  if [ -d "${FILE}" ]; then
    DFILENEW="${DFILE}-new"
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    ln -f "${FILE}/"* "${DFILENEW}/"
    ln -f "${FILE}/"* "${WFILENEW}/"
    ln -f "${FILE}/"* "${MFILENEW}/"
    rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
    echo "Replacing daily backup ${DFILE} folder this last backup..."
    mv "${DFILENEW}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} folder this last backup..."
    mv "${WFILENEW}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} folder this last backup..."
    mv "${MFILENEW}" "${MFILE}"
  else
    echo "Replacing daily backup ${DFILE} file this last backup..."
    ln -vf "${FILE}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} file this last backup..."
    ln -vf "${FILE}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} file this last backup..."
    ln -vf "${FILE}" "${MFILE}"
  fi
  # Update latest symlinks
  echo "Point last backup file to this last backup..."
  ln -svf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${BUCKET}-latest${BACKUP_SUFFIX}"
  echo "Point latest daily backup to this last backup..."
  ln -svf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${BUCKET}-latest${BACKUP_SUFFIX}"
  echo "Point latest weekly backup to this last backup..."
  ln -svf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${BUCKET}-latest${BACKUP_SUFFIX}"
  echo "Point latest monthly backup to this last backup..."
  ln -svf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${BUCKET}-latest${BACKUP_SUFFIX}"
  #Clean old files
  echo "Cleaning older files for Minio ${BUCKET} bucket..."
  find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${BUCKET}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${BUCKET}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${BUCKET}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${BUCKET}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

echo "Minio backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi
