#!/usr/bin/env python3

"""Run as nextpvr's postprocessing script. Embeds meatadata and moves file to recorded dir."""

import argparse
import os
import shlex
import sqlite3
from argparse import ArgumentParser
from os import environ
from shutil import copyfile, rmtree
from subprocess import run
from tempfile import TemporaryDirectory
from urllib.request import urlretrieve
from xml.etree import ElementTree

import magic


class Args(argparse.Namespace):
    """Args"""
    filename: str
    channel_number: str
    oid: str

parser = ArgumentParser()
parser.add_argument('filename')
parser.add_argument('channel_number')
parser.add_argument('oid')
args_ns = Args()
args, _ = parser.parse_known_args(namespace=args_ns)

def env(var_name):
    """Get env var by name"""
    try:
        return environ[var_name]
    except KeyError:
        print(f"{var_name} is not set")
        exit(1)

print(f"Post processing {args.filename}...")

RECORDED_DIR = env('RECORDED_DIR')
NEXTPVR_DIR = env('NEXTPVR_DATADIR_USERDATA').rstrip('/')

name, ext = os.path.splitext(args.filename)

conn = sqlite3.connect(os.path.join(NEXTPVR_DIR, 'npvr.db3'))

# Pull out metadata, artwork so we can embed it
result = conn.execute('select event_details from SCHEDULED_RECORDING where oid = ?', (args.oid,))
event_details, = result.fetchone()

metadata: dict[str, str] = {}

artwork: str = ''

event_xml = ElementTree.fromstring(event_details)
for item in event_xml:
    if text := item.text:
        if item.tag == 'Title':
            metadata['title'] = text
        if item.tag == 'Description':
            metadata['description'] = text
        if item.tag == 'Season':
            metadata['season_number'] = text
        if item.tag == 'Episode':
            metadata['episode_id'] = text
        if item.tag == 'DeferredArtwork':
            artwork = text

metadata_args: list[str] = []
for k, v in metadata.items():
    metadata_args += ['-metadata', f'{k}={v}']

with TemporaryDirectory() as tmpdir:

    artwork_args = []
    if artwork:
        print('Downloading ' + artwork)
        artwork_file, _ = urlretrieve(artwork)

        IMAGES = {
            'image/jpeg': 'jpg',
            'image/png': 'png'
        }

        mimetype: str = magic.from_file(artwork_file, mime=True)
        if image_ext := IMAGES.get(mimetype):
            cover = os.path.join(tmpdir, 'cover.' + image_ext)
            copyfile(artwork_file, cover)
            artwork_args = ['-i', cover, '-map', '1', '-map', '0', '-disposition:0', 'attached_pic']

    output_file = os.path.join(RECORDED_DIR, os.path.basename(name) + '.mp4')
    ff_args = ['ffmpeg', '-i', args.filename] \
        + artwork_args + metadata_args \
        + ['-dn', '-acodec', 'copy', '-vcodec', 'copy', '-y', output_file]
    print(' '.join(shlex.quote(arg) for arg in ff_args))

    run(ff_args, check=True)

os.remove(args.filename)
# If there are no other video files in its directory, delete
dirname = os.path.dirname(args.filename)
if not any(f for f in os.listdir(dirname) if f.endswith('.ts')):
    rmtree(dirname)

conn.execute('delete from SCHEDULED_RECORDING where oid = ?', (args.oid,))
conn.commit()
