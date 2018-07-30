"""Compares two image tarballs and finds how their layers differ.

Compares two images layer by layer and prints out which layers differ
and what files differ per layer.


usage: idd.py [-h] [-c] [-d] [-f] [-l MAX_LAYER] [-v] tar1 tar2

positional arguments:
  tar1                  First image tar path
  tar2                  Second image tar path

optional arguments:
  -h, --help            show this help message and exit
  -c, --cancel_cleanup  leaves all the extracted files after program finishes
                        running
  -d, --first_diff      stops after a pair of layers which differ are found
  -f, --force           run even if the images don't have the same number of
                        layers
  -l MAX_LAYER, --max_layer MAX_LAYER
                        only compares until given layer (exclusive, starting
                        at 0)
  -v, --verbose         print differences between files (as well as their
                        names)



Examples of usage:

  Basic:
      python idd.py path/to/image1.tar path/to/image2.tar

  Including file content differences:
      python -v idd.py path/to/image1.tar path/to/image2.tar

  Only compare first 4 layers, and stop after a difference was found
      python -d -l 4 idd.py path/to/image1.tar path/to/image2.tar


Relevant parts of the structure of a valid image tarball (tarball.tar):

  tarball.tar/
    manifest.json
      <layer1_id>/
        layer.tar
      <layer2_id>/
        layer.tar
    ...

The manifest.json should have a field named 'layers' which has the paths to
the layer.tar's in the same order as the layers were installed:
Ex. "layers" : ["<layer1_id>/layer.tar", "<layer2_id>/layer.tar"]
"""

from __future__ import print_function
import argparse
import atexit
import difflib
import filecmp
import json
import os
import shutil
import string
import sys
import tarfile

MAX_BIN_CHAR_PERCENTAGE_IN_HUMAN_READABLE_FILE = 0.3


class ImageTar(object):
  """Wrapper around TarFile for specific use with image tarballs.

  Attributes:
    tar_id: int - This objects id, used to determine where it stores
      its extracted contents
    contents_folder: str - The path to the folder where we store
      temporary extracted files
    tar: TarFile - The image's tarball as a file open for reading
    layers: list of str - Chronological list of the path to each
      layer's tarball within the original tar

  Class Variables:
    id_counter: int - Counter to keep track of each ImageTar's object id
    (for giving it a contents folder)
    """
  id_counter = 1

  def __init__(self, tar_path, contents_path=""):
    """Initialize an ImageTar object.

    Extracts layer information and creates a directory where
    all extracted files will be stored.

    Args:
      tar_path: str, relative or absolute path to the given tarball
      contents_path: str, path where the tar's content folder will be
        created by default, it is in the current directory
    """

    self.tar_id = ImageTar.id_counter
    ImageTar.id_counter += 1

    # Create a folder where the contents of layers in this image will be
    # extracted. If the script is called normally, would produce tar1_contents
    # and tar2_contents folders in the working directory
    # All files created by this object will be placed in here
    folder = os.path.join(contents_path, "tar{}_contents".format(
        str(self.tar_id)))

    if os.path.isdir(folder):
      shutil.rmtree(folder)
    os.mkdir(folder)

    self.contents_folder = os.path.abspath(folder)

    self.tar = tarfile.open(tar_path, mode="r")

    # Extract the list of layer paths from the manigest.json file.
    decoder = json.JSONDecoder()
    try:
      manifest = decoder.decode(
          self.tar.extractfile("manifest.json").read().decode("utf-8"))[0]
      self.layers = manifest["Layers"]
    except tarfile.ExtractError as e:
      print(
          e,
          "Unable to extract manifest.json from image {}."
          "Make sure it is a valid image tarball".format(self.tar_id),
          file=sys.stderr)

  def get_diff_layer_indicies(self, other_tar):
    """Returns a list of indicies of layers which differ between self and other_tar.

    Args:
      other_tar: ImageTar of other image we want to compare with this one

    Returns:
      An increasing list of indicies corresponding to layers
      that are in both images but have different ids.
    """
    diff_layers = []
    for i in range(min(len(self.layers), len(other_tar.layers))):
      if self.layers[i] != other_tar.layers[i]:
        diff_layers.append(i)
    return diff_layers

  def get_path_to_layer_contents(self, layer_num):
    """Returns path to contents of given layer.

    Returns the path to the root of the folder where the contents of the
    given layer are kept. If it has not yet been extracted,
    it also extracts it.
    Example path: tar1_contents/layer2 where the numbers can vary

    Args:
      layer_num: int representing the index of the layer (in order of creation)

    Returns:
      str representing path to the extracted layer contents
    """
    path = os.path.join(self.contents_folder, "layer_" + str(layer_num))

    if os.path.isdir(path):
      return path

    os.mkdir(path)
    self.tar.extract(self.layers[layer_num], path=self.contents_folder)
    layer_tar = tarfile.open(
        os.path.join(self.contents_folder, self.layers[layer_num]))
    try:
      layer_tar.extractall(path)
    except tarfile.ExtractError as e:
      print(
          "Some files were unable to be extracted from image: {} layer: {}\n".
          format(self.tar_id, layer_num),
          e,
          file=sys.stderr)
    except OSError as e:
      print(
          "Some files were unable to be extracted from image: {} layer: {}\n".
          format(self.tar_id, layer_num),
          e,
          file=sys.stderr)

    return path

  def cleanup(self, delete_artifacts=True):
    """Deletes artifacts this object produces and closes open files.

    Args:
      delete_artifacts: bool - If false,
        extracted artifacts are left for manual inspection

    Returns:
      None

    """
    self.tar.close()
    if delete_artifacts:
      shutil.rmtree(self.contents_folder)


def compdirs(left, right, diff=None, path=""):
  """Recursively compares the given directories.

  Args:
    left: str path to first directory
    right: str path to second directory
    diff: filecmp.dircmp object, if you already have one. Mainly for recursive
      calls
    path: str for recursive calls. Remembers the path from starting directory to
      the one we are currently at

  Returns:
    3-tuple of the form (left_only, right_only, diff_files) where left_only
    and right_only are lists of paths to files unique to the corresponding
    directory, and diff_files is a list of paths to common files which are
    not identical.
  """

  if diff is None:
    diff = filecmp.dircmp(left, right)

  left_only = [os.path.join(path, i) for i in diff.left_only]
  right_only = [os.path.join(path, i) for i in diff.right_only]
  diff_files = [os.path.join(path, i) for i in diff.diff_files]

  # This sometimes mislabels different files as same (since it uses cmp with
  # shallow=True), so we double check with shallow=False

  for f in diff.same_files:
    if not filecmp.cmp(
        os.path.join(left, path, f),
        os.path.join(right, path, f),
        shallow=False):
      diff_files.append(os.path.join(path, f))

  # Checks for symbolic links and adds symbolic links that point to different
  # locations to diff_files (filecmp.dircmp classifies ones that point to
  # non-existant files as funny)
  for funny_file in diff.funny_files:
    if not (os.path.islink(os.path.join(left, path, funny_file)) and
            os.path.islink(os.path.join(right, path, funny_file)) and
            os.readlink(os.path.join(left, path, funny_file)) == os.readlink(
                os.path.join(right, path, funny_file))):
      diff_files.append(os.path.join(path, funny_file))

  # Recursive call on subdirectories (dicrmp does not automatically compare
  # subdirectories, diff.diff_files only has files from the base directory)
  for diff_dir in diff.subdirs:
    new_path = os.path.join(path, diff_dir)

    # Avoid following symlinks to directories
    # (loops and redirects to outside directories)
    if os.path.islink(os.path.join(left, new_path)) or os.path.islink(
        os.path.join(right, new_path)):
      continue
    oil, oir, df = compdirs(left, right, diff.subdirs[diff_dir], new_path)

    left_only += oil
    right_only += oir
    diff_files += df

  return left_only, right_only, diff_files


def check_file_human_readable(f):
  """Returns true if under 30% of the files characters are non-printable.

  Useful for avoiding printing out binary files

  Args:
    f: file or str representing path to the file

  Returns:
    bool which is true iff under 30% of the files characters are
    non-printable/binary
  """

  if isinstance(f, str):
    f = open(f, "r")

  chars = 0
  binary_chars = 0

  for line in f:
    for char in line:
      if char not in string.printable:
        binary_chars += 1
      chars += 1

  return float(binary_chars) / float(chars) < \
        MAX_BIN_CHAR_PERCENTAGE_IN_HUMAN_READABLE_FILE


def print_diffs(file1_path, file2_path):
  """Prints out a compact diff of the files.

  Args:
    file1_path: str path to file1
    file2_path: str path to file2

  Returns:
    None
  """
  try:
    file1 = open(file1_path, "r")
    file2 = open(file2_path, "r")

    for line in difflib.unified_diff(list(file1), list(file2)):
      print(line)
    print()
  except OSError as e:
    print(e, "Failed to open file")


def main():
  """Prints out a human-readable comparison between image tarballs.
  """

  (tar1_path, tar2_path, cancel_cleanup, stop_at_first_difference, max_depth,
   print_differences, force) = parse_arguments()

  tar1 = ImageTar(tar1_path)
  tar2 = ImageTar(tar2_path)

  # Clean up the open files and artifacts (upon program exiting)
  def cleanup():
    tar1.cleanup(not cancel_cleanup)
    tar2.cleanup(not cancel_cleanup)

  atexit.register(cleanup)

  if len(tar1.layers) != len(tar2.layers):
    print("Images have different number of layers")
    if not force:
      print("Use -f | --force flag to proceed\n")
      exit(1)
  print()

  diff_layers = tar1.get_diff_layer_indicies(tar2)

  for layer in diff_layers:
    # Stop if reaches max depth or max number of differences (optional params)
    if layer >= max_depth:
      break

    # Get the 3-tuple of lists of files that differ between the layers
    files = compdirs(
        tar1.get_path_to_layer_contents(layer),
        tar2.get_path_to_layer_contents(layer))

    print("\nLayer {}:\n".format(layer))

    # If the layer has no differences to report
    if files == ([], [], []):
      print("No differences found, but layer ids are different.")

    diff_files = files[2]

    if diff_files:
      print("Common files which differ:\n")
    for f in diff_files:
      if not print_differences:
        # print the file name if verbosity was not requested
        print(f)
      else:
        # print the file name and try to see the differences between the files
        print(f + ":")

        file1_path = os.path.join(tar1.get_path_to_layer_contents(layer), f)
        file2_path = os.path.join(tar2.get_path_to_layer_contents(layer), f)

        if check_file_human_readable(file1_path) and \
            check_file_human_readable(file2_path):

          print_diffs(file1_path, file2_path)
        else:
          print("Skipping binary file.\n")
    text = ("Only in image 1:\n", "Only in image 2:\n")

    for i in range(2):
      if files[i]:
        print(text[i])
      for f in files[i]:
        print(f)
      print()

    # Stop here if the user requested so
    if stop_at_first_difference:
      break

  print()


def parse_arguments():
  """Parses command line arguments for this script.

  Returns:
    tuple containing all of the arguments
  """
  parser = argparse.ArgumentParser()

  parser.add_argument("tar1", help="First image tar path", type=str)
  parser.add_argument("tar2", help="Second image tar path", type=str)
  parser.add_argument(
      "-c",
      "--cancel_cleanup",
      help="leave all the extracted files after program finishes running",
      action="store_true")
  parser.add_argument(
      "-d",
      "--first_diff",
      help="stop after a pair of layers which differ are found",
      action="store_true")
  parser.add_argument(
      "-f",
      "--force",
      help="run even if the images don't have the same number of layers",
      action="store_true")
  parser.add_argument(
      "-l",
      "--max_layer",
      help="only compare until given layer (exclusive, starting at 0)",
      type=int,
      default=float("inf"))
  parser.add_argument(
      "-v",
      "--verbose",
      help="print differences between files (as well as their names)",
      action="store_true")

  args = parser.parse_args()

  return (args.tar1, args.tar2, args.cancel_cleanup, args.first_diff,
          args.max_layer, args.verbose, args.force)


if __name__ == "__main__":
  main()
