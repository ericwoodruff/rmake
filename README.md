rmake - rsync make
===================

rmake (rsync make) is a remote build enabler that replicates a build workspace to one or more locations and executes a build life-cycle for each location.

Life-Cycle
----------

The rmake build life-cycle executes the following phases:

* Pre-Sync Hook (optional) - locally execute a defined hook script
* Filter - establish a filter policy for the next phase
* Copy/Sync - synchronize the build location, adding and removing files as necessary
* Purge (optional) - build-derived files can optionally be discarded
* Pre-Build Hook (optional) - locally execute a defined hook script
* Build - setup the build environment and execute the build as defined in the .rmake config
* Post-Build Hook (optional) - locally execute a defined hook script (like emailing build results)

Remote Building
---------------

While building remotely incurs a small replication overhead, rsync is incredibly efficient, and the benefits are enormous:

* Enables scalabilty to more platfroms, with the option to build them in parallel
* Enables building on a different OS, and many OSes
* Eliminates excuses for not building cross-platform code on all platforms before check-in
* Eliminates the checkin thrashing that comes from trying propogate and test source code changes on multiple platfroms through version control
* Reduces the chance of losing completed source code that can come from manually copying modified files to different platforms for testing
* Promotes the usage of disposable virtual machines (VMs) as build servers
* Keeps build-derived files out of the source code tree
* Creates an inadvertant backup of a source tree should something unforseen happen to development machine
* Creates an opportunity to filter some files from the build (see below)

Filtering
---------

As part of the source tree replication, rmake has the opportunity to filter the file list based on certain policies, and even modify the file attributes as they are copied to the remote location.

"Read-only" - rmake always transfers source files to each remote location as read-only copies (ugo-w). In general, a proper build must not modify files checked into source control so rmake will help identify a misbehaving build by forcing 'permission denied' errors to source file writes.

"Git/svn status" - rmake understands both git and svn file status which enables it to enact various filter policies when replicating the source tree to the build location:

* Default - filters out .git or .svn directories. Version control meta-data is usually not needed to perform a build, and the meta-data can contain many large files that slow the initial transfer and waste space at the remote location.
* Pedantic - filters out files that are unversioned, removed or in poor status (i.e. conflicted). This emulates building from a hypothetical checkout of the pending commit in the source tree (re: Git index) -- This helps protect against the "I forgot to checkin some files" case.
* Base - an extension of the Pedantic filter, without affecting local changes in the source tree, reverts the remote build location to the branch base/HEAD revision -- This help answer the question "Did my changes break the build or functionality or was it like that when I checked out?"

Sanity Checking
---------------

rmake-check allows rmake to assert that a workstation and the remote build locations meet some minimum requirements such as:

* rsync is installed
* SSH in installed
* Each remote location is available via password-less SSH
* No remote location is a remote mount point for the local filesystem (or data loss might occur)

rmake-check is also an extensible way to validate that a remote build server meets certain custom requirments such as:

* Platform/OS version validation
* Server memory and swap space
* Server tools/packages are installed and the correct version
* etc...

Requirements
------------

* rmake is written in Bash, so a Bash interpreter is required.
* rmake requires the getopt tool.
* It makes remote connections via ssh and replicates using rsync, so both mush be installed and the master host and the build servers.
* An up-to-date git or svn client and xsltproc are recommended for the pedantic exclusion filter.
* Non-interactive SSH logins to the build servers is also required.
* If using a Windows machine as your development machine then you should have Cygwin installed before beginning the install instructions.
* The time on the build server must not be ahead of the time on your workstation, nor is it allowed to be more than 5 minutes behind. See the section below on Time.

.rmakerc
--------

The .rmakerc file is usually found in your home directory at ~/.rmakerc. This file is really just a common place to store the configuration of your build server platforms.

The typical ~/.rmakerc file defines the following components for a platform:

    platform=user@server

* "platform": the platform name
* "user@": the user to ssh to the Build Server as (optional)
* "server": the Build Server to synchronize and build with

For example:

    rhel5=ewoodruff@tmr11s2rbvm

Advanced Configuration
----------------------

In reality, rmake will find these platform identifiers from the shell environment so the .rmakerc file is not essential.

Additionally, a .rmakerc need not be placed in your home directory, but rather it can be placed in a project root directory as well. If placed in a project root such as trunk/.rmakerc, any configured settings defined in ~/.rmakerc will be inherited but can also be overridden in the project-specific version.

Typically a project-specific .rmakerc file is used to specialize the configuration for that project, such as defining a specific build path on the Build Server. See the following definitions of the allowed forms of platform definitions in rmake:

**Form 1:** Remote Host

    platform=user@server:build/path

* "platform": the platform name
* "user@": the user to ssh to the Build Server as (optional)
* "server": the Build Server to synchronize and build with
* "build/path": the location on the Build Server to place the synchronized files and perform a build (optional)

Note: Typically the build/path should not be specified. When left unspecified, rmake will automatically select a path on the Build Server that is a moral equivalent to the path to the project root on the local workstation. This allows the rmake user to not have to specify a new .rmakerc configuration for each private branch that is being developed.
Tip: If you are using rmake directly on a Build Server (Scenario 2 above, not recommended), then you will need to specify a build path because otherwise rmake will automatically choose the same path as the svn tree, which is not allowed. In that case, you can just use Form 2 below.

**Form 2:** Local Host

    platform=~/build/path

* "build/path": the location on the local workstation to place the synchronized files and perform a build (optional)

Lastly, the `RMAKE_PROXY` option can be specified if there is another location that hosts the svn tree (besides your workstation) that would be a more efficient place to rsync from. For example, my svn tree is actually NFS mounted to the ds cluster, so I proxy through comp1:

    RMAKE_PROXY=ewoodruff@comp1

Tip: The same rules apply to `RMAKE_PROXY` as a platform identifier, meaning this option supports Form 1 and Form 2 and can be overridden in a project-specific .rmakerc.

Usage Guide
-----------

**Use Case 1:** Perform a Build in a specific directory

    cd trunk/src/common
    rmake -p rhel5 clean all

**Use Case 2:** Perform the same build on all configured platforms (`RMAKE_PLATFORMS`)

    rmake -a clean all

**Use Case 3:** Purge all build-derived files from a specific directory and rebuild

    cd gensrc/sql
    rmake -Rdi all

**Caution:** Make sure you know what you are doing; using this command by mistake could require a full rebuild.

**Use Case 4:** Use rmake with vim

    :set makeprg=TERM=dumb\ rmake\ --no-decorate\ -prhel5
    :make

**Use Case 5:** Use rmake without an .rmakerc

    rhel5=user@host:path/to/build rmake -p rhel5 rpm

Time
----

When building on a different server than you are developing, time can be an issue, especially for incremental builds. It is very important to remove time differences between your Workstation and your Build Server. NTP can be useful, but nevertheless, virtual machines can sometimes have problems keeping time anyway. rmake will check for a time differential in the following ways:

* The Build Server may not be in the future, otherwise builds might always be up-to-date.
* The Build Server may not be more than 5 minutes is the past. The further is the past the Build Server is, the more it will unnecessarily rebuild.

Note: When performing a full rebuild from scratch with '-d', rmake has no need to check the time differential unless '-R' was used.

Tip: Here is an easy to set the time on your Build Server (if you have root access):

    date | ssh root@server xargs -0 date -s

A Bash alias can also be created to do this frequently:

    alias rmake='date | ssh root@server xargs -0 date -s; rmake'

Help Output
-----------

    rmake is a high-level make program that replicates a source tree
    to a remote workspace and runs the configured make command.

    Usage: rmake -a [MODE] [OPTION]... [TARGET]...
      or   rmake -p "PLATFORMS" [MODE] [OPTION]... [TARGET]...

    Modes
     -d, --clean                delete extraneous files from remote workspace(s)
     -D, --clean-only           don't transfer or make, just delete (implies -du)
     -u, --update-only          update remote workspace(s), but do not make
     -l                         list configured platforms
     -r, --resource             print the configured resource for a platform
     -w, --where-am-i           print the located workspace root
     -c                         only run rmake-check
         --version              print SVN revision
     -h, --help                 show this help

    Options
     -a                         operate on all platforms in RMAKE_PLATFORMS
     -p, --platform=NAMES       operate on NAMES
     -k, --keep-going           continue on platform error
     -P, --parallel             parallelize (implies -qk)
     -C, --directory=DIR        change to DIR before synchronizing or making
     -R, --relative             synchronize current dir instead of RMAKE_FILE_LIST
     -q                         suppress non-error messages
         --mail                 e-mail results (same as -x rmake-email.sh)

    SVN/Git Options
     -i, --pedantic             ignore/exclude files not in good standing with svn/git
     -m, --svn-meta             include some svn meta-data (.svn/ with rev. info)
         --git-meta             include all git meta-data (.git/)
     -b, --svn-base             copy svn base instead of working copy (implies -di) or
         --git-base             git stash changes before transfer

    Advanced Options
     -x, --exec=COMMAND         run "COMMAND platform exitcode timestamp server log"
         --no-decorate          don't decorate/annotate build output
         --no-pre-sync          don't run pre-sync hook
         --no-pre-make          don't run pre-make hook
         --no-post-make         don't run post-make hook
     -F, --file-list=FILES      synchronize FILES instead of RMAKE_FILE_LIST
     -v                         increase verbosity (ex. use rsync -v)
         --debug                print debug trace

