REMOTE_HOST="cloud"
REMOTE_DIR="~/sites/heiss.website/books/public_html/2024"
REMOTE_DEST=$REMOTE_HOST:$REMOTE_DIR

echo "Uploading new changes to remote server..."
echo
rsync -czrvP --delete _site/ $REMOTE_DEST
