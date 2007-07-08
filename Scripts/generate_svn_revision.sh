## $Id$

PATH="$PATH:/opt/local/bin:/usr/local/bin:/usr/local/subversion/bin:/sw/bin"
REVISION=`svnversion .`

## SVN_REVISION is a string because it may look like "4168M" or "4123:4168MS"
echo "#define SVN_REVISION \"$REVISION\"" > $SCRIPT_OUTPUT_FILE_0
echo "#define SVN_REVISION_UNQUOTED $REVISION" >> $SCRIPT_OUTPUT_FILE_0
