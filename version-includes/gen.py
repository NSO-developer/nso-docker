#!/usr/bin/env python3
"""Script to generate a bunch of YAML files containing Gitlab CI configuration
that are suitable for including from other CI configurations.

Gitlab CI supports including other files in the configuration file. We use this
to simplify maintenance of many NSO packages over time. Each package only needs
to define a archetype CI job and by including one of these prepared version
include files, the precise versions of NSO to test with doesn't have to be
specified in each repo, instead the centralized nso-docker repo can be used as
a source for NSO version information.

This script generates a bunch of different version include files. It is up to
the author of each individual NSO package to include the one suitable for their
package.

For example, we have build-all.yaml, which uses the prototypical CI job
definition called 'build' and defines jobs for all currently supported versions
of NSO.

build-all4.yaml is similar but only includes NSO 4.x versions, whereas
build-all5.yaml does the same for NSO 5.x. Since NSO 5 looks quite different
with schema-mount, it could be reasonable for some packages to only target NSO
5.

build-tot.yaml only includes the "tip" of each train, where a train is the
combination of a major and minor version number. Patch releases are not
considered for tip-of-train as they are not supposed to be used by the wide
masses. For example, if we have 4.7, 4.7.1, 4.7.2 and 4.7.2.1 as well as 5.2.1,
the tip-of-train would include 4.7.2 and 5.2.1.
"""

import json

ci_template = """{name}-{version}
  extends: .build
  variables:
    NSO_VERSION: "{version}"

"""

def vsn_split(version):
    """
    """
    return list(map(lambda x: int(x), version.split(".")))

def f_major(interesting_version, versions):
    """Filter based on the major version

    Filtering on version 4 means 4.7.5 is returned while 5.2.1 is not
    """
    return filter(lambda x: x[0] == interesting_version, versions)

def f_tot(versions):
    """Filter based on tip-of-train
    Version numbers are major.minor.maintenance.path
    Tip-of-train is considered to be the latest major.minor.maintenance combo
    This filter will only return the tip-of-train releases so for example, only
    4.7.6 will be released if the input is 4.7.5 and 4.7.6
    """
    tot = {}
    for version in versions:
        mm = (version[0], version[1])
        if mm not in tot:
            tot[mm] = version
        if tot[mm] < version:
            tot[mm] = version
    return tot


def formatter(version):
    version_string = ".".join(map(lambda x: str(x), version))
    return ci_template.format(name='build', version=version_string)

with open("versions.json") as f:
    versions = sorted(list(map(lambda x: vsn_split(x), json.load(f))))

# all versions
with open("build-all.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), versions)))

# all 4 versions
with open("build-all4.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), f_major(4, versions))))

# all 5 versions
with open("build-all5.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), f_major(5, versions))))

# all tip-of-train versions
with open("build-tot.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), f_tot(versions))))

# all tip-of-train 4 versions
with open("build-tot4.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), f_tot(f_major(5, versions)))))

# all tip-of-train 5 versions
with open("build-tot5.yaml", "w") as f:
    f.write("".join(map(lambda x: formatter(x), f_tot(f_major(5, versions)))))
