# GoldenPod - a podcast client in perl

GoldenPod is a command line podcast client written in perl. It allows you to
easily manage and download podcasts from the command line. It can download
podcasts from standard RSS(-like) feeds, or it can attempt to parse any other
cleartext document (ie. XML or HTML) for a list of audio files and download
those.

Information on how to configure goldenpod can be found in the manpage. If
GoldenPod is installed globally on your system just type "man goldenpod", if
not then type either "man ./goldenpod.1" or "perldoc ./goldenpod".

## Bug reports

If you find a bug, please report it at L<https://www.zerodogg.org/goldenpod/bugs>

## Installation instructions

Run `make install` in the GoldenPod directory. This will detect if you are
running as a user or root, and do the right thing™.

## License

GoldenPod is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

GoldenPod is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
goldenpod. If not, see
[http://www.gnu.org/licenses/](http://www.gnu.org/licenses/).
