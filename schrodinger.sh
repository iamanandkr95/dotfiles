# Script contains functions, aliases and environment variables to setup development environment for
# Schrodinger core suite.
# Script relies on helper functions from .bash_utils.sh file.
# In order to debug an issue set _SCHRODINGER_DEBUG=1.


# Show debug messages.
_SCHRODINGER_DEBUG=0


# Set the value of _SCHRODINGER_HOME based on the operating system. _SCHRODINGER_HOME is the
# directory in which schrodinger core suite development happens.
if _is_darwin; then
    _SCHRODINGER_HOME=/Users/$USER/builds
elif _is_linux || _is_windows; then
    _SCHRODINGER_HOME=/scr/$USER/builds
else
    _error "Unknown OS. Script is designed to work on Linux, Darwin and Windows."
    return 1
fi


# ==============================================================================
# Helper functions
# ==============================================================================


# SCHRODINGER debug that prints only if $_SCHRODINGER_DEBUG is set to 1.
# Usage: _sdgr_debug <message>
function _sdgr_debug() {
    if [[ $_SCHRODINGER_DEBUG -eq 1 ]]; then
        _debug "$1"
    fi
}


# Check if an environement variable is set. If not then print an error message.
# Usage: _check_variable <variable_name> <error message>
function _check_variable() {
    _sdgr_debug "_check_variable"

    local error_msg=$2
    if [[ -z "${!1}" ]]; then
        _error "$1 is not set."
        if [[ ! -z $error_msg ]]; then
            _error "$error_msg"
        fi
        return 1
    fi
}


# Retrieve the branch name from the $SCHRODINGER environment variable.
# Usage: _get_build_branch_name
function _get_build_branch_name() {
    _sdgr_debug "_get_build_branch_name"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    # $SCHRODINGER is a path like "$_SCHRODINGER_HOME/branch-name/build".
    echo $(echo $SCHRODINGER | awk -F'/' '{print $(NF-1)}')
}


# ==============================================================================
# SCHRODINGER build environment
# ==============================================================================

# Set the license file path. It looks for a *.lic file in $_SCHRODINGER_HOME/licenses/.
# Usage: _init_license
function _init_license() {
    _sdgr_debug "_init_license"

    local license_fpath=$_SCHRODINGER_HOME/licenses/
    mkdir -p $license_fpath

    if [[ -z $(find $license_fpath -name "*.lic") ]]; then
        _warning "No license file found in $license_fpath."
        return 1
    fi
    
    export SCHRODINGER_LICENSE=$license_fpath
    _info "SCHRODINGER_LICENSE is set to $SCHRODINGER_LICENSE"
}

_init_license


# Selects a build for the shell session.
# Usage: _select_build <branch_name> (e.g. _select_build 2021-3)
function _select_build() {
    _sdgr_debug "_select_build"

    if [[ -z "$1" ]]; then
        _error "Build is not specified. Usage: _select_build 2021-3"
        return 1
    fi

    branch=$1;
    export SCHRODINGER_LIB=$_SCHRODINGER_HOME/software/lib;
    export SCHRODINGER_SRC=$_SCHRODINGER_HOME/$branch/source;
    export SCHRODINGER=$_SCHRODINGER_HOME/$branch/build;

    _info "SCHRODINGER_LIB is set to $SCHRODINGER_LIB"
    _info "SCHRODINGER_SRC is set to $SCHRODINGER_SRC"
    _info "SCHRODINGER is set to $SCHRODINGER"
}


# Create aliases for available releases in $_SCHRODINGER_HOME. (2024-1 -> 24-1)
# Usage: _create_release_aliases
function _create_release_aliases() {
    _info "Creating release aliases..."
    for dir in $(find $_SCHRODINGER_HOME -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9]"); do
        local alias_name=$(echo $dir | awk -F'/' '{print $NF}')
        local short_alias_name=${alias_name:2}
        alias $short_alias_name="_select_build $alias_name"
        _info "\t$short_alias_name -> $alias_name"
    done
}

_create_release_aliases


# ==============================================================================
# SCHRODINGER specific aliases
# ==============================================================================

# Navigation Source
alias src='cd $SCHRODINGER_SRC'
alias mm='cd ${SCHRODINGER_SRC}/mmshare'
alias ss='cd ${SCHRODINGER_SRC}/scisol-src'
# Navigation Build
alias bld='cd $SCHRODINGER'
alias mmb='cd ${SCHRODINGER}/mmshare-v*/'
alias mmt='cd ${SCHRODINGER}/mmshare-v*/python/test'
alias ssb='cd ${SCHRODINGER}/scisol-v*/'

# Schrodinger command
alias srun='${SCHRODINGER}/run'
alias sjsc='${SCHRODINGER}/jsc'  # Job Server Client

# Building
alias mp='cd $SCHRODINGER/mmshare-v*/ && make python && cd -'
alias mps='cd $SCHRODINGER/mmshare-v*/ && make python-scripts && cd -'
alias mpm='cd $SCHRODINGER/mmshare-v*/ && make python-modules && cd -'


if _is_linux; then
    alias centos7='make -C $_SCHRODINGER_HOME/buildenvs/centos7 shell'
fi


# ==============================================================================
# Source Build Environment
# ==============================================================================

# On Ubuntu we can build only in the centos7 environment. We however want to use the same build
# environment values for things like QtDesigner, Python, Yapf, etc. So we create a file to write
# the environment values in the CentOS7 environment and then source it in the Ubuntu environment.
# Usage: _get_centos7_build_env_path
function _get_centos7_build_env_path() {
    _sdgr_debug "_get_centos7_build_env_path"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    local branch=$(_get_build_branch_name)
    echo "$_SCHRODINGER_HOME/.centos7_build_env_$branch"
}


# Source the build environment.
# Usage: ssch
function ssch() {
    _sdgr_debug "ssch"

    _check_variable SCHRODINGER_SRC
    [[ $? -eq 0 ]] || return 1

    if _is_darwin || _is_windows; then
        source $SCHRODINGER_SRC/mmshare/build_env
        return 0
    fi

    if ! _is_linux; then
        _error "Unknown OS."
        return 1
    fi

    if [[ -f /.dockerenv ]]; then
        source $SCHRODINGER_SRC/mmshare/build_env
        # CentOS7 container. Write environment variable to a file so that we can source it
        # in the Ubuntu environment.
        build_env_path=$(_get_centos7_build_env_path)
        echo "export QTDIR=$QTDIR" > $build_env_path;
        echo "export SCHRODINGER_BUILD_ENV_VERSION=$SCHRODINGER_BUILD_ENV_VERSION" >> $build_env_path;
    else
        # Ubuntu. Source the build environment file from the CentOS7 environment.
        build_env_path=$(_get_centos7_build_env_path)
        if [[ -f $build_env_path ]]; then
            source $build_env_path
            short_build_env_version="${SCHRODINGER_BUILD_ENV_VERSION:0:7}"
            export PATH=$SCHRODINGER/buildvenv/$short_build_env_version/bin:$PATH
        else
            _warning "Build environment file $build_env_path does not exist." \
                    "You won't be able to use designer, yapf, etc."
        fi
        source $SCHRODINGER_SRC/mmshare/build_env
    fi
}

# ==============================================================================
# Experimental Building
# ==============================================================================

# Background builder
alias bg-builder='srun $SCHRODINGER_SRC/mmshare/build_tools/background_builder.py'
alias pyrun='srun $SCHRODINGER_SRC/mmshare/build_tools/background_run.py'
alias autorun='srun $SCHRODINGER_SRC/mmshare/build_tools/autobuild.py'
alias pymaestro='srun $SCHRODINGER_SRC/mmshare/build_tools/background_run.py maestro'


# ==============================================================================
# Maestro
# ==============================================================================

# Open Maestro attached to the console
# Usage: maestro
function maestro() {
    _sdgr_debug "maestro"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    if _is_darwin; then
        ${SCHRODINGER}/maestro -console
    elif _is_linux; then
        ${SCHRODINGER}/maestro
    elif _is_windows; then
        ${SCHRODINGER}/maestro_console.exe
    else
        _error "Unknown OS"
    fi
}


# ==============================================================================
# Qt Designer
# ==============================================================================

# Open Qt Designer
# Usage: sdesigner
function sdesigner() {
    _sdgr_debug "sdesigner"

    _check_variable QTDIR "Did you forget to source the build environment?"
    [[ $? -eq 0 ]] || return 1

    if _is_darwin; then
        open $QTDIR/bin/Designer.app
    elif _is_linux; then
        if [[ -f /.dockerenv ]]; then
            _error "Can't run designer in the CentOS7 container."
            return 1
        fi
        # On Ubuntu set the QTDIR and LD_LIBRARY_PATH environment variables of the build environment
        # so that we can run designer.
        export PATH=$QTDIR/bin:$PATH
        export LD_LIBRARY_PATH=$QTDIR/lib:$LD_LIBRARY_PATH
        $QTDIR/bin/designer
    elif _is_windows; then
        srun $QTDIR/bin/designer
    else
        _error "Unknown OS"
    fi
}


# ==============================================================================
# Testing
# ==============================================================================

# We write the output of mtest to a file so that we can see the output of the tests
# in a separate window.
# Usage: _get_mtest_log_path
function _get_mtest_log_path() {
    _sdgr_debug "_get_mtest_log_path"

    _check_variable SCHRODINGER_SRC
    [[ $? -eq 0 ]] || return 1

    echo $(dirname $SCHRODINGER_SRC)/mtest.log
}


# Open mtest log file in Visual Studio Code if it is installed. Otherwise open it with the
# default editor.
# Usage: mtest_log
function mtest_log() {
    _sdgr_debug "mtest_log"

    _check_variable SCHRODINGER_SRC
    [[ $? -eq 0 ]] || return 1

    _open_text_file $(_get_mtest_log_path)
}


# make test TEST_ARGS
# Usage: mtest [TEST_ARGS]
function mtest() {
    _sdgr_debug "mtest"

    _check_variable SCHRODINGER_SRC
    [[ $? -eq 0 ]] || return 1

    args="${*}"
    if [[ $args == *"/scisol/"* ]]; then
        args="--post-test $args"
    fi

    make test TEST_ARGS="$args" | tee $(_get_mtest_log_path)
}


# ==============================================================================
# Buildinger
# ==============================================================================

# Buildinger that setups autocomplete in IDE.
# Usage: _post_buildinger
function _post_buildinger() {
    _sdgr_debug "_post_buildinger"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    local site_packages=$SCHRODINGER/internal/lib/python*/site-packages

    _sdgr_debug "Setting up Qt autocomplete in IDE"
    if [ -z "$(find $site_packages/schrodinger/Qt -name *.pyi)" ]; then
        cp -f $(find $SCHRODINGER_LIB -name *.pyi) $site_packages/schrodinger/Qt > /dev/null 2>&1
    fi
    if [ -z "$(find $site_packages/schrodinger/Qt -name *.pyi)" ]; then
        _warning "Failed to setup Qt autocomplete in IDE."
    fi

    _sdgr_debug "Setting up scisol autocomplete in IDE"
    if [ -d $SCHRODINGER/scisol-v* ]; then
        # if scisol is installed then symlink scisol-src modules
        ln -s -f $SCHRODINGER/scisol-v*/lib/*/python_packages/scisol/*/ \
            $site_packages/schrodinger/application/scisol/packages > /dev/null 2>&1
    fi
    if [ -z "$(find $site_packages/schrodinger/application/scisol/packages -name *.pyi)" ]; then
        _warning "Failed to setup scisol autocomplete in IDE."
    fi
}


# Buildinger that setups autocomplete in IDE.
# Usage: buildinger [BUILDINGER_ARGS]
function buildinger() {
    _sdgr_debug "buildinger"

    local args="${*}"
    $SCHRODINGER_SRC/mmshare/build_tools/buildinger.sh $args

    if [[ $? -eq 0 ]]; then
        _post_buildinger
    fi

    # Notify when done.
    if _is_darwin; then
        show_notification "Buildinger" "Buildinger done"
    fi

}


# Show build logs. We show mmshare and maestro logs.
# Usage: buildinger_logs
function buildinger_logs() {
    _sdgr_debug "buildinger_logs"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    local mm_log_fpath=$SCHRODINGER/mmshare-v*/make_mmshare_all.log
    local maestro_log_fpath=$SCHRODINGER/maestro-v*/make_maestro_all.log

    tail -f $mm_log_fpath $maestro_log_fpath
}


# Get next build number in the branch
function mmv() {
    _sdgr_debug "mmv"

    bld=${1:-master}
    curl -s "https://cgit.schrodinger.com/cgit/mmshare/plain/version.h?h=$bld" \
        | grep "#define MMSHARE_VERSION" \
        | awk '{ printf("%03d\n", $3%1000+1) }'
}


# Switch all repos in $SCHRODINGER_SRC to the specified branch.
# Usage: switch_branches <branch_name>
function switch_branches() {
    _sdgr_debug "switch_branches"

    # Switch all repos in $SCHRODINGER_SRC to the new branch.
    if [[ -z $1 ]]; then
        _error "Specify branch to checkout..."
        return 1
    fi

    _check_variable SCHRODINGER_SRC
    [[ $? -eq 0 ]] || return 1

    _info "\$SCHRODINGER_SRC is set to $SCHRODINGER_SRC"

    _sdgr_debug "Process and update repositories:\n"
    for repo in $SCHRODINGER_SRC/*; do
        _info "Processing $repo ..."
        git -C $repo fetch; git -C $repo checkout $1;
        if [[ $? -ne 0 ]]; then
            _error "Error checking out $1 in $repo. Is this a Schrodinger suite repo?"
        fi
        echo "\n          ***********************************************\n"
    done;
}


# ==============================================================================
# Schrodinger Virtualenv
# ==============================================================================

# Create Schrodinger virtualenv
# Usage: _create_venv
function _create_venv() {
    _sdgr_debug "_create_venv"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    local branch=$(_get_build_branch_name)
    srun schrodinger_virtualenv.py ~/.virtualenvs/$branch

    if [[ $? -ne 0 ]]; then
        _error "Error creating Schrodinger virtualenv for $branch."
        return 1
    else
        _success  "Created Schrodinger virtualenv in ~/.virtualenvs/$branch"
    fi
}


# Activate Schrodinger Virtualenv. If it doesn't exist for $SCHRODINGER then create one.
# Usage: svenv [create]
function svenv() {
    _sdgr_debug "svenv"

    _check_variable SCHRODINGER
    [[ $? -eq 0 ]] || return 1

    # If "create" is passed as an argument then create the virtualenv.
    if [[ $1 == "create" || ! -d ~/.virtualenvs/$_get_build_branch_name ]]; then
        _create_venv
    fi

    source ~/.virtualenvs/$branch_name/bin/activate
    if [[ $? -ne 0 ]]; then
        _error "Error activating Schrodinger virtualenv for $branch_name."
        return 1
    else
        _success "Activated Schrodinger virtualenv for $branch_name."
    fi
}


# ==============================================================================
# Setup Developer Environment
# ==============================================================================

# Setup core suite developer environment in tmux.
# Usage: setup_dev_env [branch_name]
function stmux() {
    _sdgr_debug "stmux"

    branch=$1
    if [ -z $branch ]; then
        _error "No branch name is given. Usage: stmux <branch_name>"
        return 1
    fi

    if ! tmux has-session -t $branch 2>/dev/null; then
        # Create a new session with src, build and test windows and source the build environment
        local name=${branch:2}

        # Sourcing the build environment on Linux outside the centos7 environment doesn't work.
        function _attempt_to_source_build_env() {
            local window_idx=$1
            if _is_linux; then
                tmux send-keys -t $branch:$window_idx "ssch; clear"  C-m
            else
                tmux send-keys -t $branch:$window_idx "ssch && clear"  C-m
            fi
        }

        # src
        tmux new-session -s $branch -n src -d
        tmux send-keys -t $branch:0 "$name && mm"  C-m
        _attempt_to_source_build_env 0

        # build & test
        tmux new-window -t $branch:1 -n build/test
        if _is_linux; then
            # On Linux we can only build inside the centos7 environment
            tmux send-keys -t $branch:1 "centos7"  C-m
        fi
        tmux send-keys -t $branch:1 "$name && ssch && mmt && clear"  C-m

        # Maestro
        tmux new-window -t $branch:2 -n maestro
        tmux send-keys -t $branch:2 "$name"  C-m
        _attempt_to_source_build_env 2

        # ipython
        tmux new-window -t $branch:3 -n ipython
        tmux send-keys -t $branch:3 "$name"  C-m
        _attempt_to_source_build_env 3
        if [[ $? -eq 0 ]]; then
            tmux send-keys -t $branch:3 "srun ipython"  C-m
        else
            _error "Failed to source build environment. Can't run ipython."
        fi

        # Misc
        tmux new-window -t $branch:4 -n misc
        tmux send-keys -t $branch:4 "$name"  C-m
        _attempt_to_source_build_env 4

        tmux select-window -t $branch:0
    fi
    tmux detach-client -a -s $branch
    tmux attach-session -t $branch
}
