We have a different index file for latex and for html/epub. I tried with
".. only::" but it doesn't work properly (probably because of a bug,
probably triggered by the fact that the ".. only::" contains a toctree).
The Makefile automatically replaces the index with the one needed.
