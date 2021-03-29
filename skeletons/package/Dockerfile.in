ARG NSO_IMAGE_PATH
ARG NSO_VERSION

# DEP_START
# DEP_END


# Compile local packages in the build stage
FROM ${NSO_IMAGE_PATH}cisco-nso-dev:${NSO_VERSION} AS build
ARG PKG_FILE

# DEP_INC_START
# DEP_INC_END

COPY / /src

# Provide a fake environment for pylint and similar.
#
# All packages are normally assumed to be in the same directory
# (/var/opt/ncs/packages) which means that if you have a dependency to another
# directory, the relative path is '../dep-pkg'. When the code of a package is
# included as a dependency, the code is required not only at run time but must
# also be accessible at build time such that linters and other static checkers
# can find all dependencies.
#
# In our build here we keep packages, test-packages and includes separate as
# that greatly simplifies later producing the testnso and package images. In
# order to allow linters to run, we fake the view of a normal directory
# structure and placement of packages (in the same directory) by using symlinks.
#
# Create /src/test-packages in case it doesn't exist (not copied in, thus
# doesn't exist in source git repo) since this is otherwise a common cause of
# issues.
RUN mkdir -p /var/opt/ncs/packages /includes /src/test-packages; \
  for PKG_SRC in $(find /includes /src/packages /src/test-packages -mindepth 1 -maxdepth 1 -type d); do \
    ln -s ${PKG_SRC} /var/opt/ncs/packages/; \
    ln -s ${PKG_SRC} /src/packages 2>/dev/null; \
    ln -s ${PKG_SRC} /src/test-packages 2>/dev/null; \
  done; true

# Build Python virtualenvs for our packages (not includes). As it isn't possible
# to move a venv due to its use of absolute paths, we must pretend the packages
# are all in /var/opt/ncs/packages, as that is the final location where they
# will be placed. build-pyvenv fakes this by rewriting the path after building
# the venv.
# The "--mount=type=cache ..." option is a Docker BuildKit feature that mounts a
# (cached) path into the build container. In this case we use it to cache files
# downloaded by pip.
RUN --mount=type=cache,target=/root/.cache/pip \
  for PKG_SRC in $(find /src/packages /src/test-packages -mindepth 1 -maxdepth 1 -type d); do \
  /src/nid/build-pyvenv ${PKG_SRC}; \
  done

# Compile packages and inject build-meta-data.xml if it doesn't exist. For each
# package, detect if a python virtualenv is available and activate it if found.
# We prefer a virtualenv meant for development, expected in 'pyvenv-dev', and
# will fall back to 'pyvenv', in case one exists. We iterate over the source
# directories rather than /var/opt/ncs/packages, since this way we don't get the
# includes.
# Each package may implement the strip target to clean up extra files generated
# by ncsc, pylint and mypy. For example, ncsc-out, .mypy_cache, .pylint.d.
RUN for PKG_SRC in $(find /src/packages /src/test-packages -mindepth 1 -maxdepth 1 -type d | xargs --no-run-if-empty -n1 basename | awk '{ print "/var/opt/ncs/packages/"$1 }'); do \
  if [ -f "${PKG_SRC}/pyvenv-dev/bin/activate" ]; then . ${PKG_SRC}/pyvenv-dev/bin/activate; \
  elif [ -f "${PKG_SRC}/pyvenv/bin/activate" ]; then . ${PKG_SRC}/pyvenv/bin/activate; \
  fi; \
  make -C ${PKG_SRC}/src clean; \
  make -C ${PKG_SRC}/src || exit 1; \
  if make -C ${PKG_SRC}/src -n test >/dev/null 2>&1; then \
    echo "Found 'test' target, running tests..."; \
    make -C ${PKG_SRC}/src test || exit 1; \
  fi; \
  deactivate >/dev/null 2>&1; \
  rm -rf ${PKG_SRC}/pyvenv-dev; \
  if make -C ${PKG_SRC}/src -n strip >/dev/null 2>&1; then \
    echo "Found 'strip' target, stripping..."; \
    make -C ${PKG_SRC}/src strip || exit 1; \
  fi; \
  make -f /src/nid/bmd.mk -C ${PKG_SRC} build-meta-data.xml; \
  done

RUN for PKG_LINK in $(find /src/packages /src/test-packages -mindepth 1 -maxdepth 1 -type l); do \
  rm ${PKG_LINK}; \
  done

# produce an NSO image that comes loaded with our package - perfect for our
# testing, but probably not anything beyond that since you typically want more
# NSO packages for a production environment
FROM ${NSO_IMAGE_PATH}cisco-nso-base:${NSO_VERSION} AS testnso

COPY --from=build /includes /var/opt/ncs/packages/
COPY --from=build /src/packages/ /var/opt/ncs/packages/
COPY --from=build /src/test-packages/ /var/opt/ncs/packages/

# Copy in extra files as an overlay, for example additions to
# /etc/ncs/pre-ncs-start.d/
COPY extra-files /

# Run the 'compose' target for *all* packages. In contrast to running the build
# and test targets only on the packages that are part of this repository this
# will run on included packages as well. This is an optional target implemented
# when the package needs to run additional steps that are not part of the
# building recipes. For example the package may change its behavior depending on
# the types of NEDs loaded in the final NSO image. The set of NEDs is only known
# when building the NSO image and not in the package repository.
RUN for PKG in $(find /var/opt/ncs/packages -mindepth 1 -maxdepth 1 -type d); do \
  if make -C ${PKG}/src -n compose >/dev/null 2>&1; then \
    echo "Found 'compose' target in ${PKG}/src, executing ..."; \
    make -C ${PKG}/src compose || exit 1; \
  fi; \
done

# build a minimal image that only contains the package itself - perfect way to
# distribute the compiled package by relying on Docker package registry
# infrastructure
FROM scratch AS package
COPY --from=build /src/packages/ /var/opt/ncs/packages/
