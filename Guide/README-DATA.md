
This is the "README-DATA.md" file for overpass Slackware package.

IMPORTANT: This is a work in progress, may also have inaccurate information.

The "data" is the subject in this file; That is OpenStreetMap (OSM) data.
Overpass database is initialed using OSM data file. Just the basic information is mentioned here
about OSM data files - books are written about the subject, what they are made of and their format.
You get to meet Osmium! And finally the internet sources where to get your data file are mentioned.

OpenStreetMap(OSM) data basic element is made of three types:
    - nodes (defining points in space),
    - ways (defining linear features and area boundaries), and
    - relations (which are sometimes used to explain how other elements work together).

Each element is defined using TAGS; a tag is a pair of NAME and VALUE, and each element has an ID number.
The very basic element point (node) will have at least two tags, logtitude and latitude plus an ID number.
Usually elements have a lot more than those tags.

### Terminology
**Meta, Attic and ChangeSet:**

Meta: extra information such as objects versions, timestamps; create or change times,
and the editing user information (user id and name) are all considered meta information or meta for short.
OSM data files with "meta" can have full or partial meta information, sometimes part or all meta information
is intentionally removed. For example; user information like name, user id are removed for privacey reasons and laws.

Attic: An attic in a house is where one keeps his / her old junk. Attic data is historical data,
things change, street names even city name can change (Bombay to Mumbai, India), other things
may change in the database, element version number.
Quoting from overpassAPI installation:

```
Since Overpass API v0.7.50, it is possible to also retain previous object versions, the so called
attic versions, in the database. Previous object versions are accessible via [date:...], [diff:...],
[adiff:...] as well as some filters like (changed:...)."
```
It is important to note here that initialing overpass database with attic (historical) data from
an extract (limited area) file is not supported. An expermintal approach is shown in this guide
where queries mentioned above are only available on the command line using "osm3s_query" program.

ChangeSet: Objects have tags which can change in values, deleted or new tags get
added to the object. Changes in current release OSM file from the previous release
is the ChangeSet. Change can be over time too, an object state can change over a
period of time - say one day - an object gets a new tag added or another tag gets
new value (changed); this is how (.osc) OSM Change files are produced.
OSM Change files are small and can be used to updated previous OSM file and
databases that uses them. Change file will include instruction to add, remove or change elements or their tags.

The data is shipped in files, OSM data files come in multiple formats and sizes. There are many tools (programs) that work with OSM data files.
Two standout as must know; [Osmosis (Java)](https://wiki.openstreetmap.org/wiki/Osmosis) and [Osmium (C++)](https://wiki.openstreetmap.org/wiki/Osmium) they both basicly have the
same functionality. I have a slackware package repository here on github for ["osmium tools"](https://github.com/waelhammoudeh/osmium-tool_slackbuild), if you need it.
The manual page from osmium-file-formats (part of osmium tools) defines them nicely:

```
$ man osmium-file-formats

OSMIUM-FILE-FORMATS(5)       OSMIUM-FILE-FORMATS(5)

NAME
       osmium-file-formats - OSM file formats known to Osmium

FILE TYPES
       OSM uses three types of files for its main data:

       Data files
              These  are  the  most  common files.  They contain the OSM data from a specific point in time.
              This can either be a planet file containing all OSM data or some kind of extract.  At most one
              version of every object (node, way, or relation) is contained in this file.  Deleted objects are not
              in this file.  The usual suffix used is .osm.

       History files
              These  files  contain  not  only the current version of an object, but their history, too.  So for
              any object (node, way, or relation) there can be zero or more versions in this file.  Deleted
              objects can also be in this file.  The usual suffix used is .osm or .osh.  Because sometimes the
              same suffix  is used as for normal data files (.osm) and because there is no clear indicator in
              the header, it is not always clear what type of file you have in front of you.

       Change files
              Sometimes called diff files or replication diffs these files contain the changes between one state
              of the OSM database and another  state. Change files can contains several versions of an object
              and also deleted objects.  The usual suffix used is .osc.

       All these files have in common that they contain OSM objects (nodes, ways, and relations).  History files
       and change files can contain several versions of the same object and also deleted objects, data files can’t.
```
---                                                                         ---

More about this to come[^note]
[^note]: **File size:**
* Depends on the area, city smaller than country.
* (.pbf) file always smaller then (.osm) file.
* Files with history (attic) always bigger than latest with meta.

[^note]: **Internet Sources:**
 - http://download.openstreetmap.fr/extracts/
 - https://download.geofabrik.de/
 - https://download.bbbike.org/osm/
many other sites.

[^note]: **File storage:**
* Keep the file used to inital DB - may need it again.
* Hard to tell what the database size will be, but it is going to always grow larger.
* Database initialed with attic data will be the largest size, then meta and no meta is smallest.