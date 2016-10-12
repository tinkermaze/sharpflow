#!/usr/bin/env bash

##########################################################################
# Custom shell script to bootstrap a Cake build.
#
# Script downloads .NET Core SDK if missing, restores helper packages
# for build pipeline (including Cake) and starts build.cake script.
#
##########################################################################

# define default arguments
TARGET="Default"
CONFIGURATION="Release"
VERBOSITY="verbose"
SCRIPT_ARGUMENTS=()

# parse arguments
for i in "$@"; do
    case $1 in
        -t|--target) TARGET="$2"; shift ;;
        -c|--configuration) CONFIGURATION="$2"; shift ;;
        -v|--verbosity) VERBOSITY="$2"; shift ;;
        --) shift; SCRIPT_ARGUMENTS+=("$@"); break ;;
        *) SCRIPT_ARGUMENTS+=("$1") ;;
    esac
    shift
done

SOLUTION_ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

###########################################################################
# Prepare .NET Core SDK
###########################################################################

DOTNET_VERSION_FOUND=""
DOTNET_LOCAL_PATH=$SOLUTION_ROOT/.dotnet
DOTNET_LOCAL_EXE=$DOTNET_LOCAL_PATH/dotnet
DOTNET_INSTALLER_URI="https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.sh"

if command -v "$DOTNET_LOCAL_EXE" >/dev/null 2>&1; then

    DOTNET_VERSION_FOUND=$("$DOTNET_LOCAL_EXE" --version)

    echo "Found .NET Core SDK version $DOTNET_VERSION_FOUND (in $DOTNET_LOCAL_PATH)"

    export PATH="$DOTNET_LOCAL_PATH":$PATH

elif command -v dotnet >/dev/null 2>&1; then

    DOTNET_VERSION_FOUND=$(dotnet --version)

    echo "Found .NET Core SDK version $DOTNET_VERSION_FOUND (system-wide)"

fi

if [[ -z "$DOTNET_VERSION_FOUND" ]]; then

    echo "Installing the latest .NET Core SDK (into $DOTNET_LOCAL_PATH)"

    if [[ -d "$DOTNET_LOCAL_PATH" ]]; then
        rm -rf "$DOTNET_LOCAL_PATH"
    fi

    if [[ ! -d "$DOTNET_LOCAL_PATH" ]]; then
        mkdir "$DOTNET_LOCAL_PATH"
    fi

    # download installer script
    curl -Lsfo "$DOTNET_LOCAL_PATH/dotnet-install.sh" "$DOTNET_INSTALLER_URI"

    # and install .NET Core SDK into local "DOTNET_LOCAL_PATH" folder
    bash "$DOTNET_LOCAL_PATH/dotnet-install.sh" --version latest --install-dir "$DOTNET_LOCAL_PATH" --no-path

    export PATH="$DOTNET_LOCAL_PATH":$PATH

fi

export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1

###########################################################################
# Prepare Cake and helper tools
###########################################################################

BUILD_PATH=$SOLUTION_ROOT/build
TOOLS_PATH=$SOLUTION_ROOT/tools

TOOLS_PROJECT_JSON=$TOOLS_PATH/project.json
TOOLS_PROJECT_JSON_SRC=$BUILD_PATH/tools_project.json

CAKE_FEED="https://api.nuget.org/v3/index.json"

echo "Preparing Cake and build tools"

if [ ! -d "$TOOLS_PATH" ]; then
    echo "Creating tools directory"
    mkdir "$TOOLS_PATH"
fi

cp "$TOOLS_PROJECT_JSON_SRC" "$TOOLS_PROJECT_JSON"

echo "Restoring build tools (into $TOOLS_PATH)"
dotnet restore "$TOOLS_PATH" --packages "$TOOLS_PATH" --verbosity Warning -f "$CAKE_FEED"
if [ $? -ne 0 ]; then
    echo "Error occured while restoring build tools"
    exit 1
fi

CAKE_EXE=$( ls $TOOLS_PATH/Cake.CoreCLR/*/Cake.dll | sort | tail -n 1 )

# make sure that Cake has been installed
if [[ ! -f "$CAKE_EXE" ]]; then
    echo "Could not find Cake.exe at '$CAKE_EXE'"
    exit 1
fi

###########################################################################
# Run build script
###########################################################################

