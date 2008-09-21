#!/bin/bash
#set -x

SF_ACCOUNT=${SF_ACCOUNT:-$USER}
LCDPROC_DIR=${LCDPROC_DIR:-$HOME/lcdproc}
NIGHTLY_DIR=${NIGHTLY_DIR:-$LCDPROC_DIR/nightly}

CVS=/usr/bin/cvs
MAKE=/usr/bin/make
PERL=/usr/bin/perl
GUNZIP=/bin/gunzip
BZIP2=/usr/bin/bzip2
CVS2CL=/usr/bin/cvs2cl
RSYNC=/usr/bin/rsync

TODAY=`/bin/date`
#####
# Branch, can be stable-0-4-x, stable-0-5-x or current (default)
BRANCH=${1:-current}

test -d ${NIGHTLY_DIR}/${BRANCH}/  &&  cd ${NIGHTLY_DIR}/${BRANCH}/

# make sure, we're in an LCDproc source directory
if [ -e README ] && [ -e ChangeLog ] && [ -e LCDd.conf ]; then

  # Clean up (just in case)
  rm -f lcdproc-*.tar.gz lcdproc-*.tar.bz2

  # Fetch the changes (ignore the file we store the changes in)
  ${CVS} update -d 2>&1 | grep -v '^? nightly-cvsChanges.txt' > nightly-cvsChanges.txt

  # Add warning and changes to the README file
  mv README README.nightly-temp
  echo "################################################"    > README
  echo "# WARNING! WARNING! WARNING! WARNING! WARNING! #"    >> README
  echo "#                                              #"    >> README
  echo "# This is an automated nightly distribution    #"    >> README
  printf '# %-44s #\n' "made with the ${BRANCH} CVS branch." >> README
  printf '# %-44s #\n' "Date:   ${TODAY}"                    >> README
  echo "# NO WARANTIES AT ALL.  Expect this to crash.  #"    >> README
  echo "# Please report problems to the mailing list.  #"    >> README
  echo "#                                              #"    >> README
  echo "#      http://lcdproc.omnipotent.net/          #"    >> README
  echo "################################################"    >> README
  echo >> README
  cat README.nightly-temp >> README
  echo >> README
  echo "Here's what CVS update said (Check ChangeLog for more infos):" >> README
  echo >> README
  cat nightly-cvsChanges.txt >> README

  # Produce a ChangeLog for yesterday
  mv ChangeLog ChangeLog.nightly-temp
  echo "Changes since yesterday:" > ChangeLog
  echo >> ChangeLog
  ${CVS2CL} -l '-d yesterday<=' --stdout 2>/dev/null >> ChangeLog

  # Change the version number to CVS-${BRANCH}-${DATE}
  cp -a configure.in configure.in.nightly-temp
  BRANCH=${BRANCH} \
  ${PERL} -MPOSIX -i -p \
          -e '$version = "CVS-".$ENV{BRANCH}."-".strftime("%Y%m%d", localtime);
              s/(AM_INIT_AUTOMAKE\s*)\(\s*(\[?lcdproc\]?)\s*,\s*[\w\d.-]+\s*\)/$1($2, $version)/; 
              s/(AC_INIT\s*)\(\s*(\[?lcdproc\]?)\s*,\s*[\w\d.-]+\s*\)/$1($2, $version)/;
              s/(AC_INIT\s*)\(\s*(\[?lcdproc\]?)\s*,\s*[\w\d.-]+(\s*[^)]+)\s*\)/$1($2, $version$3)/;' \
          configure.in

  # Debian-specific stuff
  for dir in debian scripts/debian ; do
    # Increase version number in debian/changelog accordingly
    if [ -d "$dir" ] && [ -e "$dir/changelog" ]; then 
      cp -a $dir/changelog debian_changelog.nightly-temp
      ${PERL} -MPOSIX -i -p \
              -e '$date = strftime("%Y%m%d", localtime);
                  s/\((\d\.\d\.\d{1,2})([+~])cvs\d{8}(.*?)\)/(${1}${2}cvs${date}${3})/i if ($. == 1);' \
              $dir/changelog
    fi

    # Make debian/rules executable
    test -e $dir/rules  &&  chmod +x $dir/rules
  done 

  # Re-generate the autotools files
  sh autogen.sh >/dev/null
  ./configure --silent >/dev/null

  # Creation of the distribution
  ${MAKE} dist dist-bzip2 >/dev/null &>/dev/null
  mv lcdproc-*.tar.gz lcdproc-CVS-${BRANCH}.tar.gz
  mv lcdproc-*.tar.bz2 lcdproc-CVS-${BRANCH}.tar.bz2

  # Date of the last nightly
  echo "${TODAY}" > last-nightly.txt

  # Upload to sf.net
  ${RSYNC} -q lcdproc-CVS-${BRANCH}.tar.gz lcdproc-CVS-${BRANCH}.tar.bz2 \
              last-nightly.txt \
              ${SF_ACCOUNT},lcdproc@web.sourceforge.net:htdocs/nightly/

  mv lcdproc-CVS-${BRANCH}.tar.gz ${LCDPROC_DIR}/

  # Cleanup
  mv configure.in.nightly-temp configure.in
  mv README.nightly-temp README
  mv ChangeLog.nightly-temp ChangeLog
  rm -f nightly-cvsChanges.txt last-nightly.txt
  for dir in debian scripts/debian ; do
    test -d $dir  &&  mv debian_changelog.nightly-temp $dir/changelog
  done 

  # remove files generated by ./configure --silent
  ${MAKE} distclean

  # re-create files accidentially deleted
  ${CVS} update -d &> /dev/null

  # build configure (& Makefile.in's ?) based on original configure.in from CVS
  sh autogen.sh >/dev/null
 
fi

# EOF
