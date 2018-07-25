#!/bin/sh

usage() {
  echo "Usage:
    $0 -v <version> -t <tag> -r <repository-url> chart-base-directory
    -r --> mandatory
    -v --> mandatory
    -t --> mandatory
    chart-base-directory --> mandatory
    or
    $0 -h|? ---> for help
    "
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "h?v:t:r:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    v)  version=$OPTARG
        ;;
    t)  tag=$OPTARG
        ;;
    r)  repository=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

basedir=$@

# Check mandatory parameters
missing_args=0
if [ ! -d $basedir ]; then
  echo "$basedir is not a directory!\n"
  missing_args=1
fi
if [ -z "$version" ]; then
   echo "-v is mandatory\n"
   missing_args=1
fi
if [ -z "$tag" ]; then
   echo "-t is mandatory\n"
   missing_args=1
fi
if [ -z "$repository" ]; then
     echo "-r is mandatory\n"
     missing_args=1
fi
if [ $missing_args -eq 1 ]; then
  usage
  exit 1
fi

echo "version              = "$version
echo "tag                  = "$tag
echo "repository-url       = "$repository
echo "chart-base-directory = "$basedir

echo "updating Chart.yaml file(s)..."
find $basedir -name Chart.yaml | xargs  sed  -i -e "s/^version:.*/version: $version/"

echo "updating values.yaml file(s)..."
find $basedir -name values.yaml | xargs  sed  -i -E "s/^(\s*)tag:\s*".*"/\1tag: \"$tag\"/"

findReq="find $basedir -name requirements.yaml"
requirement=`$findReq`
if [ -n "$requirement" ]; then
  echo "updating requirement.yaml file(s)..."
  find $basedir -name requirements.yaml | xargs  sed  -i -E "s/^(\s*)version:.*/\1version: $version/"
  find $basedir -name requirements.yaml | xargs  sed  -i -E "s|^(\s*)repository:.*|\1repository: $repository|"

  helm dep up $basedir

fi

echo "Packaging with helm..."
output=`helm package --version=$version $basedir`
echo $output

outputfile=`echo $output | sed -E "s|(.*)/(.*)|\2|"`
push_cmd="curl --data-binary \"@$outputfile\" $repository/api/charts"
echo "Pushing to the repository..."
eval $push_cmd
echo