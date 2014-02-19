#!/bin/bash

# apt-cyg: install tool for cygwin similar to debian apt-get

# The MIT License (MIT)
# 
# Copyright (c) 2013 Trans-code Design
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 

# this script requires some packages

WGET=`which wget 2> /dev/null`
BZIP2=`which bzip2 2> /dev/null`
TAR=`which tar 2> /dev/null`
GAWK=`which awk 2> /dev/null`
XZ=`which xz 2> /dev/null`
if test "-$WGET-" = "--" || test "-$BZIP2-" = "--" || test "-$TAR-" = "--" \
  || test "-$GAWK-" = "--" || test "-$XZ-" = "--"
then
  echo You must install wget, tar, gawk, xz and bzip2 to use apt-cyg.
  exit 1
fi


function usage()
{
  echo apt-cyg: Installs and removes Cygwin packages.
  echo "  \"apt-cyg install <package names>\" to install packages"
  echo "  \"apt-cyg remove <package names>\" to remove packages"
  echo "  \"apt-cyg update\" to update setup.ini"
  echo "  \"apt-cyg show\" to show installed packages"
  echo "  \"apt-cyg find <patterns>\" to find packages matching patterns"
  echo "  \"apt-cyg describe <patterns>\" to describe packages matching patterns"
  echo "  \"apt-cyg packageof <commands or files>\" to locate parent packages"
  echo "Options:"
  echo "  --mirror, -m <url> : set mirror"
  echo "  --cache, -c <dir>  : set cache"
  echo "  --file, -f <file>  : read package names from file"
  echo "  --noupdate, -u     : don't update setup.ini from mirror"
  echo "  --help"
  echo "  --version"
}



function version()
{
  echo "apt-cyg version 0.59"
  echo "Written by Stephen Jungels"
  echo ""
  echo "Copyright (c) 2005-9 Stephen Jungels.  Released under the GPL."
}


function findworkspace()
{
  # default working directory and mirror
  mirror=http://mirrors.kernel.org/sourceware/cygwin
  cache=/setup
  
  # work wherever setup worked last, if possible
  
  if test -e /etc/setup/last-cache
  then
    tmp="`head -1 /etc/setup/last-cache`"
    cache="`cygpath -au "$tmp"`"
  fi
  
  if test -e /etc/setup/last-mirror
  then
    mirror="`head -1 /etc/setup/last-mirror`"
  fi
  mirrordir="`echo "$mirror" | sed -e "s/:/%3a/g" -e "s:/:%2f:g"`"
  
  echo Working directory is $cache
  echo Mirror is $mirror
  mkdir -p "$cache/$mirrordir"
  cd "$cache/$mirrordir"
}


function getsetup() 
{

  ARCH=`uname -m | grep _64`
  if test "-$ARCH-" = "--"
  then
    arch="x86"
  else
    arch="x86_64"
  fi

  if test "$noscripts" == "0" -a "$noupdate" == "0"
  then
    touch setup.ini
    mv setup.ini setup.ini-save
    wget -N $mirror/$arch/setup.bz2
    if test -e setup.bz2 && test $? -eq 0
    then
      bunzip2 setup.bz2
      mv setup setup.ini
      echo Updated setup.ini
    else
      wget -N $mirror/$arch/setup.ini
      if test -e setup.ini && test $? -eq 0
      then
        echo Updated setup.ini
      else
        mv setup.ini-save setup.ini
        echo Error updating setup.ini, reverting
      fi
    fi
  fi
}


function checkpackages()
{
  if test "-$packages-" = "--"
  then
    echo Nothing to do, exiting
    exit 0
  fi
}


# process options

noscripts=0
noupdate=0
file=""
dofile=0
command=""
filepackages=""
packages=""

while test $# -gt 0
do
  case "$1" in

    --mirror|-m)
      echo "$2" > /etc/setup/last-mirror
      shift ; shift
    ;;

    --cache|-c)
      cygpath -aw "$2" > /etc/setup/last-cache
      shift ; shift
    ;;

    --noscripts)
      noscripts=1
      shift
    ;;

    --noupdate|-u)
      noupdate=1
      shift
    ;;

    --help)
      usage
      exit 0
    ;;

    --version)
      version
      exit 0
    ;;

    --file|-f)
      if ! test "-$2-" = "--"
      then
        file="$2"
        dofile=1
        shift
      else
        echo 1>&2 No file name provided, ignoring $1
      fi
      shift
    ;;

    update|show|find|describe|packageof|install|remove)
      if test "-$command-" = "--"
      then
        command=$1
      else
        packages="$packages $1"
      fi
      shift

    ;;

    *)
      packages="$packages $1"
      shift

    ;;

  esac
done


if test $dofile = 1
then
  if test -f "$file"
  then
    filepackages="$filepackages `cat "$file" | awk '{printf "%s ", $0}'`"
  else
    echo File $file not found, skipping
  fi
  packages="$packages $filepackages"
fi


case "$command" in

  update)

    findworkspace
    getsetup

  ;;


  show)

    echo 1>&2 The following packages are installed:
    cat /etc/setup/installed.db | awk '/[^ ]+ [^ ]+ 0/ {print $1}'

  ;;


  find)

    checkpackages
    findworkspace
    getsetup

    for pkg in $packages
    do
      echo ""
      echo Searching for installed packages matching $pkg:
      awk '/[^ ]+ [^ ]+ 0/ {if ($1 ~ query) print $1}' query="$pkg" /etc/setup/installed.db
      echo ""
      echo Searching for installable packages matching $pkg:
      cat setup.ini | awk -v query="$pkg" \
        'BEGIN{RS="\n\n@ "; FS="\n"; ORS="\n"} {if ($1 ~ query) {print $1}}'
    done

  ;;


  describe)

    checkpackages
    findworkspace
    getsetup
    for pkg in $packages
    do
      echo ""
      cat setup.ini | awk -v query="$pkg" \
        'BEGIN{RS="\n\n@ "; FS="\n"; ORS="\n"} {if ($1 ~ query) {print $0 "\n"}}'
    done

  ;;


  packageof)

    checkpackages
    for pkg in $packages
    do
      key=`which "$pkg" 2>/dev/null | sed "s:^/::"`
      if test "-$key-" = "--"
      then
        key="$pkg"
      fi
      for manifest in /etc/setup/*.lst.gz
      do
        found=`cat $manifest | gzip -d | grep -c "$key"`
        if test $found -gt 0
        then
          package=`echo $manifest | sed -e "s:/etc/setup/::" -e "s/.lst.gz//"`
          echo Found $key in the package $package
        fi
      done
    done

  ;;


  install)

    checkpackages
    findworkspace
    getsetup

    for pkg in $packages
    do

    already=`grep -c "^$pkg " /etc/setup/installed.db`
    if test $already -ge 1
    then
      echo Package $pkg is already installed, skipping
      continue
    fi
    echo ""
    echo Installing $pkg

    # look for package and save desc file

    mkdir -p "release/$pkg"
    cat setup.ini | awk > "release/$pkg/desc" -v package="$pkg" \
      'BEGIN{RS="\n\n@ "; FS="\n"} {if ($1 == package) {desc = $0; px++}} \
       END {if (px == 1 && desc != "") print desc; else print "Package not found"}' 
    
    desc=`cat "release/$pkg/desc"`
    if test "-$desc-" = "-Package not found-"
    then
      echo Package $pkg not found or ambiguous name, exiting
      rm -r "release/$pkg"
      exit 1
    fi
    echo Found package $pkg

    # download and unpack the bz2 or xz file

    # pick the latest version, which comes first
    install=`cat "release/$pkg/desc" | awk '/^install: / { print $2; exit }'` 

    if test "-$install-" = "--"
    then
      echo "Could not find \"install\" in package description: obsolete package?"
      exit 1
    fi

    file=`basename $install`
    cd "release/$pkg"
    wget -nc $mirror/$install
    
    # check the md5
    digest=`cat "desc" | awk '/^install: / { print $4; exit }'` 
    digactual=`md5sum $file | awk '{print $1}'`
    if ! test $digest = $digactual
    then
      echo MD5 sum did not match, exiting
      exit 1
    fi
    
    echo "Unpacking..."
    #determine file type
    if [ "${file##*.}" == "xz" ]; then
      cat $file | tar > "/etc/setup/$pkg.lst" xvJf - -C /
    else
      cat $file | bunzip2 | tar > "/etc/setup/$pkg.lst" xvf - -C /
    fi
    gzip -f "/etc/setup/$pkg.lst"
    cd ../..
    
    
    # update the package database
    
    cat /etc/setup/installed.db | awk > /tmp/awk.$$ -v pkg="$pkg" -v bz=$file \
      '{if (ins != 1 && pkg < $1) {print pkg " " bz " 0"; ins=1}; print $0} \
       END{if (ins != 1) print pkg " " bz " 0"}'
    mv /etc/setup/installed.db /etc/setup/installed.db-save
    mv /tmp/awk.$$ /etc/setup/installed.db
    
    
    # recursively install required packages
    
    echo > /tmp/awk.$$ '/^requires: / {s=gensub("(requires: )?([^ ]+) ?", "\\2 ", "g", $0); print s}'
    requires=`cat "release/$pkg/desc" | awk -f /tmp/awk.$$`
    
    warn=0
    if ! test "-$requires-" = "--"
    then
      echo Package $pkg requires the following packages, installing:
      echo $requires
      for package in $requires
      do
        already=`grep -c "^$package " /etc/setup/installed.db`
        if test $already -ge 1
        then
          echo Package $package is already installed, skipping
          continue
        fi
        apt-cyg --noscripts install $package
        if ! test $? = 0 ; then warn=1; fi
      done
    fi
    if ! test $warn = 0
    then
      echo "Warning: some required packages did not install, continuing"
    fi
    
    # run all postinstall scripts
    
    pis=`ls /etc/postinstall/*.sh 2>/dev/null | wc -l`
    if test $pis -gt 0 && ! test $noscripts -eq 1
    then
      echo Running postinstall scripts
      for script in /etc/postinstall/*.sh
      do
        $script
        mv $script $script.done
      done
    fi
    
    echo Package $pkg installed

    done

  ;;


  remove)

    checkpackages
    for pkg in $packages
    do

    already=`grep -c "^$pkg " /etc/setup/installed.db`
    if test $already = 0
    then
      echo Package $pkg is not installed, skipping
      continue
    fi

    dontremove="cygwin coreutils gawk bzip2 tar wget bash"
    for req in $dontremove
    do
      if test "-$pkg-" = "-$req-"
      then
        echo apt-cyg cannot remove package $pkg, exiting
        exit 1
      fi
    done

    if ! test -e "/etc/setup/$pkg.lst.gz"
    then
      echo Package manifest missing, cannot remove $pkg.  Exiting
      exit 1
    fi
    echo Removing $pkg

    # run preremove scripts

    if test -e "/etc/preremove/$pkg.sh"
    then
      "/etc/preremove/$pkg.sh"
      rm "/etc/preremove/$pkg.sh"
    fi

    cat "/etc/setup/$pkg.lst.gz" | gzip -d | awk '/[^\/]$/ {print "rm -f \"/" $0 "\""}' | sh
    rm "/etc/setup/$pkg.lst.gz"
    rm -f /etc/postinstall/$pkg.sh.done
    cat /etc/setup/installed.db | awk > /tmp/awk.$$ -v pkg="$pkg" '{if (pkg != $1) print $0}'
    mv /etc/setup/installed.db /etc/setup/installed.db-save
    mv /tmp/awk.$$ /etc/setup/installed.db
    echo Package $pkg removed

    done

  ;;

  *)

    usage

  ;;

esac

