rmake - rsync make
===================


make (rsync make) is a distributed make tool that synchronizes a master git or svn tree view to any build resource that you have ssh access to and remotely invokes the build process on that build resource.
It is designed to be run on your workstation, rather than on a specific build server.

Benefits
--------

* Copy the master workspace to one or more build locations.
* Clean one or more build locations.
* Build in one or more build locations.
* Works like make from the current working directory on one's workstation.
* Can build multiple platforms serially or in parallel.
* Bash auto-completion support.
* Extensible to any number of platforms.
* Encapsulates build details like initializing Cygwin env on Windows
* Separates the build trees from the developer's sandbox; keeps the svn tree pure.
* Supports emailing results from parallel builds.
* Understands git and svn status to exclude files that are unversioned or in poor status (conflicted).
* By default does not transfer git or svn metadata (which includes the base revision copy).
* Can validate build servers meet build requirements:
   * Proper RPMs installed
   * Password-less ssh access
   * etc.

How It Works
------------

make uses a master/shadow architecture and intentionally does not transfer any git/svn meta-data to build resources.
Therefore, changes to a specific platform cannot be committed from a build resource, but rather from the master working copy instead.
The idea is a sort of 'write once, build everywhere' philosophy.

This approach has the great advantage that the master copy never gets polluted with build derived files, making it extremely easy to see what source files are new and what has been changed using git or svn; this means that the .gitignore file and the svn:ignore property has virtually no use to rmake users.

Note: rmake copies files to the build servers with read-only permissions to discourage and prevent accidental changes of files on the server that are not suited to be committed back to the source repository.

Hypothetical Checkouts
----------------------

rmake can clean the build trees to match the master copy exactly. It can even go further and refuse to copy, or even delete from the shadow copy, the files that are not in "good standing" with git or svn (such as unversioned, ignored or conflicted files). This allows a build to be run on a build server as if it was checked out from the changes pending in the master workspace/sandbox. This helps protect against the 'I forgot to checkin some files' case.

Is/Is Not
---------

rmake can be used:
* to make a single module on a single platform
* to make a single module on multiple platforms, in serial or parallel
* to validate changes as a pre-commit step
* to efficiently produce bits for multiple architectures to test in a mixed 32-bit/64-bit environment
* to validate that changes build from scratch (by cleaning all build-derived resources beforehand)
* to sanity check compilation of all platforms from a single svn working copy

rmake is not:
* project, architecture or build server specific
* just for building remotely, separation between your svn tree and build tree is always a good idea
* different than running 'make' directly, all command-line options are forwarded to the build tool

Requirements
------------

* rmake is written in Bash, so a Bash interpreter is required.
* rmake requires the getopt tool.
* It makes remote connections via ssh and replicates using rsync, so both mush be installed and the master host and the build servers.
* An up-to-date git or svn client and xsltproc are recommended for the pedantic exclusion filter.
* Non-interactive SSH logins to the build servers is also required.
* If using a windows machine as your development machine then you should have cygwin installed before beginning the install instructions.
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

Additionally, a .rmakerc need not be placed in your home directory, but rather it can be placed in a project root directory as well. If placed in a project root such as trunk/sns/.rmakerc, any configured settings defined in ~/.rmakerc will be inherited but can also be overridden in the project-specific version.

Typically a project-specific .rmakerc file is used to specialize the configuration for that project, such as defining a specific build path on the Build Server. See the following definitions of the allowed forms of platform definitions in rmake:

Form 1: Remote Host

    `platform=user@server:build/path`

* "platform": the platform name
* "user@": the user to ssh to the Build Server as (optional)
* "server": the Build Server to synchronize and build with
* "build/path": the location on the Build Server to place the synchronized files and perform a build (optional)

Note: Typically the build/path should not be specified. When left unspecified, rmake will automatically select a path on the Build Server that is a moral equivalent to the path to the project root on the local workstation. This allows the rmake user to not have to specify a new .rmakerc configuration for each private branch that is being developed.
Tip: If you are using rmake directly on a Build Server (Scenario 2 above, not recommended), then you will need to specify a build path because otherwise rmake will automatically choose the same path as the svn tree, which is not allowed. In that case, you can just use Form 2 below.

Form 2: Local Host

    `platform=~/build/path`

* "build/path": the location on the local workstation to place the synchronized files and perform a build (optional)

Lastly, the `RMAKE_PROXY` option can be specified if there is another location that hosts the svn tree (besides your workstation) that would be a more efficient place to rsync from. For example, my svn tree is actually NFS mounted to the ds cluster, so I proxy through comp1:

`RMAKE_PROXY=ewoodruff@comp1`
Tip: The same rules apply to `RMAKE_PROXY` as a platform identifier, meaning this option supports Form 1 and Form 2 and can be overridden in a project-specific .rmakerc.

Usage Guide
-----------

Use Case 1: Perform a Build in a specific directory

    cd trunk/klondike/src/common
    rmake -p rhel5 clean all

Use Case 2: Perform the same build on all configured platforms (`RMAKE_PLATFORMS`)

    rmake -a clean all

Use Case 3: Purge all build-derived files from a specific directory and rebuild

    cd ../mxauthz
    rmake -Rdi all

Caution: Make sure you know what you are doing; using this command by mistake could require a full rebuild.

Use Case 4: Use rmake with vim

    :set makeprg=TERM=dumb\ rmake\ --no-decorate\ -prhel5
    :make

Use Case 5: Use rmake without an .rmakerc

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

    alias rmake='date | ssh root@server xargs -0 date -s; rmake'|
