# Copyright 2017 The Bazel Authors. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Checks the specified image for security vulnerabilities."""

import argparse
import json
import subprocess
import sys
import logging
import yaml

import distutils.version as ver


# Severities
_LOW = 'LOW'
_MEDIUM = 'MEDIUM'
_HIGH = 'HIGH'
_CRITICAL = 'CRITICAL'

_SEV_MAP = {
    _LOW: 0,
    _MEDIUM: 1,
    _HIGH: 2,
    _CRITICAL: 3,
}

# Drydock only scans the main repository, but none of the mirrors.
# Swap out any mirrors for gcr.io when scanning.
_CANONICAL_IMAGE_REPOSITORY = {
    'l.gcr.io/google': 'launcher.gcr.io/google',
    'eu.gcr.io/google-appengine': 'gcr.io/google-appengine',
    'us.gcr.io/google-appengine': 'gcr.io/google-appengine',
    'asia.gcr.io/google-appengine': 'gcr.io/google-appengine'
}

REPOSITORIES_TO_IGNORE = {
    'us-mirror.gcr.io/library'
}


def gcloud_path():
  """Returns the path to the gcloud command. Requires gcloud to be on system PATH"""
  return 'gcloud'


def _sub_image(full_image):
  repo, image = full_image.rsplit('/', 1)
  if repo in REPOSITORIES_TO_IGNORE:
    logging.info('Ignoring repository %s', repo)
    return None
  repo = _CANONICAL_IMAGE_REPOSITORY.get(repo, repo)
  new_image = '/'.join((repo, image))
  if new_image != full_image:
    logging.info('Checking %s instead of %s', new_image, full_image)
  return new_image


def _run_gcloud(cmd):
  full_cmd = [gcloud_path(), 'alpha', 'container', 'images',
              '--format=json'] + cmd
  output = subprocess.check_output(full_cmd)
  return json.loads(output)


def _find_base_image(image):
  """Finds the base image of the given image.

  Args:
    image: The name of the image to find the base of.

  Returns:
    The name of the base image if it exists, otherwise None.
  """

  parsed = _run_gcloud(['describe', '--show-image-basis', image])
  img = parsed['image_basis_summary'].get('base_images')

  if not img:
    return None

  base_img_url = img[0]['derivedImage']['baseResourceUrl']
  base_img = base_img_url[len('https://'):]
  return _sub_image(base_img)


def _check_for_vulnz(image, severity, whitelist):
  """Checks drydock for image vulnerabilities.

  Args:
    image: full name of the docker image
    severity: the severity of vulnerability to trigger failure
    whitelist: list of CVEs to ignore for this test

  Returns:
    Map of vulnerabilities, if present.
  """

  logging.info('CHECKING %s', image)
  unpatched = _check_image(image, severity, whitelist)
  if not unpatched:
    return unpatched

  base_image = _find_base_image(image)
  base_unpatched = {}
  if base_image:
    base_unpatched = _check_image(base_image, severity, whitelist)
  else:
    logging.info('Could not find base image for %s', image)

  count = 0
  for k, vuln in unpatched.items():
    if k not in base_unpatched.keys():
      count += 1
      logging.info(format_vuln(vuln))
    else:
      logging.info('Vulnerability %s exists in the base '
                   'image. Skipping.', k)

  if count > 0:
    logging.info('Found %s unpatched vulnerabilities in %s. Run '
                 '[gcloud alpha container images describe %s] '
                 'to see the full list.', count, image, image)

    return unpatched


def format_vuln(vuln):
  """Formats a vulnerability dictionary into a human-readable string.

  Args:
    vuln: vulnerability dict returned from drydock.

  Returns:
    Human readable string.
  """

  packages = ''
  fixed_packages = ''

  for v in vuln['vulnerabilityDetails']['packageIssue']:
    packages = ' '.join([packages, '{0} ({1})'.format(
        v['affectedLocation']['package'],
        _get_version_number(v['affectedLocation']['version']))])

    fixed_packages = ' '.join([fixed_packages, '{0} ({1})'.format(
        v['fixedLocation']['package'],
        _get_version_number(v['fixedLocation']['version']))])

  return """
Vulnerability found.
CVE: {0}
SEVERITY: {1}
PACKAGES: {2}
FIXED PACKAGES: {3}
  """.format(
      vuln['noteName'],
      vuln['vulnerabilityDetails']['severity'],
      packages,
      fixed_packages)


def _check_image(image, severity, whitelist):
  """Checks drydock for image vulnerabilities.

  Args:
    image: full name of the docker image
    severity: the severity of vulnerability to trigger failure
    whitelist: list of CVEs to ignore for this test

  Returns:
    Map of vulnerabilities, if present.
  """

  parsed = _run_gcloud(['describe', image, '--show-all-metadata'])
  unpatched = {}

  vuln_analysis = parsed.get('package_vulnerability_summary', {})

  # If there are no fixed vulnz, we can immediately quit.
  total_vulnz = vuln_analysis.get('total_vulnerability_found', 0)
  unfixed_vulnz = vuln_analysis.get('not_fixed_vulnerability_count', 0)
  if  total_vulnz <= unfixed_vulnz:
    return unpatched

  severities = _get_relevant_severities(severity)
  vulnz = vuln_analysis['vulnerabilities']

  for s in severities:
    for v in vulnz.get(s, []):
      vuln = v['vulnerabilityDetails']
      if not _check_vuln_is_valid(vuln):
        continue

      if v['noteName'] in whitelist:
        continue

      unpatched[v['noteName']] = v

  return unpatched


def _get_relevant_severities(severity):
  return [k for k, v in _SEV_MAP.iteritems()
          if v >= _SEV_MAP.get(severity, 1)]


def _check_vuln_is_valid(vuln):
  """Checks whether the given vulnerability is valid.

  Args:
    vuln: The vulnerability json.

  Returns:
    boolean, whether it is valid.
  """
  for pkg in vuln.get('packageIssue', []):

    affected_location = pkg.get('affectedLocation')
    fixed_location = pkg.get('fixedLocation')

    if affected_location and fixed_location:
      # First, make sure the vulnerability is patched
      if not fixed_location['version'].get('name'):
        return False

      # Make sure the fixed version is later than the affected version
      affected_version = _get_version_number(affected_location['version'])
      fixed_version = _get_version_number(fixed_location['version'])

      if not fixed_version:
        return False

      if ver.LooseVersion(fixed_version) > ver.LooseVersion(affected_version):
        return True

  logging.info('Vulnerability %s is already fixed. '
               'The affected package: %s is greater '
               'than the fixed package: %s',
               vuln.get('vulnerability'),
               affected_version,
               fixed_version)
  return False


def _get_version_number(version_obj):
  # Only name is required for a version, epoch and revision are both optional.
  epoch = version_obj.get('epoch', '')
  name = version_obj.get('name', '')
  revision = version_obj.get('revision', '')
  delimiter1 = ':' if epoch else ''
  delimiter2 = '-' if revision else ''

  return ''.join([str(epoch), delimiter1, name, delimiter2, str(revision)])

def _generate_yaml_output(output_yaml, vulnerabilities):
  """Generate a YAML file mapping the key "tags" to the list of types of
  vulnerabilities found.

  Args:
    output_yaml: Path to the output YAML file to generate.
    vulnerabilities: A dictionary mapping the name of the CVE entry to details
                     about the vulnerability.
  """
  tags = set()
  for v in vulnerabilities.itervalues():
    details = v["vulnerabilityDetails"]
    # The service that consumes the metadata expects the tags as follows:
    # LOW -> cveLow
    # MEDIUM -> sveMedium
    # and so on...
    sev = str(details['severity'])
    tags.add("cve{}".format(sev.lower().capitalize()))
  result = {"tags": list(tags)}
  logging.info("Creating YAML output {}".format(output_yaml))
  with open(output_yaml, "w") as ofp:
    ofp.write(yaml.dump(result))

def security_check(image, severity=_MEDIUM, whitelist_file='whitelist.json',
                   output_yaml=None):
  """Main security check function.

  Args:
    image: full name of the docker image
    severity: the severity of vulnerability to trigger failure
    whitelist_file: file with list of whitelisted CVE
    output_yaml: Output file which will be populated with a list of types of
                 vulnerability that exist for the given image.

  Returns:
    Map of vulnerabilities, if present.
  """

  try:
    logging.info("Loading whitelist JSON {}".format(whitelist_file))
    whitelist = json.load(open(whitelist_file, 'r'))
  except IOError:
    whitelist = []
  logging.info('whitelist=%s', whitelist)

  result = _check_for_vulnz(_sub_image(image), severity, whitelist)

  if output_yaml:
    logging.info("Creating YAML output {}".format(output_yaml))
    _generate_yaml_output(output_yaml, result)
  return result


def _main():
  """Main."""
  logging.basicConfig(level=logging.INFO)
  parser = argparse.ArgumentParser()
  parser.add_argument('image', help='The image to test')
  parser.add_argument('--severity',
                      choices=[_LOW, _MEDIUM, _HIGH, _CRITICAL],
                      default=_MEDIUM,
                      help='The minimum severity to filter on.')
  parser.add_argument('--whitelist-file', dest='whitelist',
                      help='The path to the whitelist json file',
                      default='whitelist.json')
  parser.add_argument('--output-yaml', dest='output_yaml',
                      help='The path to the output YAML file to'+\
                      ' generate with a list of tags indicating the types of'+\
                      ' vulnerability fixes available for the given image.')
  args = parser.parse_args()
  security_check(args.image, args.severity, args.whitelist,
                            args.output_yaml)


if __name__ == '__main__':
  sys.exit(_main())
