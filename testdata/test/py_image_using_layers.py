"""Ensure the "six" module can be imported.

Used to end to end test python dependencies to py_image work when specified
as layers. https://github.com/bazelbuild/rules_docker/issues/161
"""

import six

if __name__ == "__main__":
    print("Successfully imported {} {}.".format(six.__name__, six.__version__))
