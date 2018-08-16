=========================
Book on Django Deployment
=========================

Get the book
============

Get the compiled book at the "releases" page.

Compiling the source
====================

::

    apt install texlive-latex-extra
    mkvirtualenv ddbook
    pip install -r requirements.txt
    make latexpdf
    make epub

You can compile with Docker instead

::

    docker build . -t django-deployment-book
    docker run -v "$(pwd):/opt/django" --rm django-deployment-book

After the above, the PDF should be in ``_build/latex`` and the epub in
``_build/epub``.

Contributing
============

If you want something to be fixed or added, please add an issue.

If you fix or add something, please add a pull request. When fixing/adding
configuration and code snippets, please use (and fix) ``testscript`` to verify
that things work.

Copyright and license
=====================

Please see file ``meta.rst``.
