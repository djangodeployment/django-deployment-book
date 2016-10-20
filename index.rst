====================================================
Deploying Django on a single Debian or Ubuntu server
====================================================

Getting started
===============

I want you to understand how Django deployment works, and in order for
you to understand it we'll need to experiment. So you will need a Debian
or Ubuntu server on which to experiment. You could create a virtual
machine on your personal system, but it will be easier and more
instructive if you have a virtual machine on the network, and a domain
name that points to it. So go to Hetzner, Digital Ocean, or whatever is
your favourite provider, and get a virtual server. Also get a domain
name and set it to point to the virtual server. In the rest of this book
I will be using "yourowndomain.com" instead of the more accurate "the
domain name under which your Django project is running".

.. hint:: Debian or Ubuntu?

   These two operating systems are practically the same system. You have
   probably already chosen one of the two to work with, and there is no
   reason to reconsider.

   If you haven't chosen yet, and you want to know nothing about this,
   go ahead and pick up the latest LTS version of Ubuntu, which
   currently is 16.04 (and will continue to be so until April 2018).

   The reason I recommend Ubuntu is mostly that it is more popular and
   therefore has better support by virtual server providers. Ubuntu's
   Long Term Support versions also have five years of support instead of
   only three for Debian (though recently Debian has started to offer
   LTS support but it's kind of unofficial). On the other hand I feel
   that Ubuntu sometimes rushes a little bit too much to get the latest
   software versions in the operating system release, whereas Debian can
   be a little bit more stable; but this is just a feeling, I have no
   hard data. I use Debian, but this is a personal preference because
   sometimes I'm too much of a perfectionist (with deadlines) and I want
   things my own way.

Experimenting means we will be trying things. We will be installing your
Django project and do things with it, and then we will be deleting it
and reinstalling it to try things differently as we move on. You must
have mastered setting up a development server from scratch. You should
be able to setup your Django project on a newly installed machine within
a couple of minutes at most, with a sequence of commands similar to the
following::

   apt-get install git python3 virtualenvwrapper
   git clone [your_project's_repository]
   cd your_project's_working_directory
   mkvirtualenv --system-site-packages myproject
   pip install -r requirements.txt
   python3 manage.py migrate
   python3 manage.py runserver

It doesn't matter if you use Python 2 instead of 3, or ``mercurial`` (or
even, horrors, FTP) instead of ``git``, or plain ``virtualenv`` instead
of virtualenvwrapper, or if you don't use ``--system-site-packages``.
What *is* important is that you have a grip on a sequence of commands
similar to the above and get your development server running in one
minute. We will be using ``virtualenv`` heavily; if you aren't
comfortable with ``virtualenv``, I have a good introduction for you at
the Appendix; go read it now.

So, you have your virtual server, and you have a sequence of commands
that can install a Django development server for your project.  Go ahead
and do so on the virtual server. You don't need to be the root user to
do so, better do it as a normal user, exactly as if you were going to do
development; but if you only have a root user on the virtual server, no
worry, use the root user, and do your job in the file:`/root` directory.

Now, make sure ``DEBUG=True``, and instead of running the development
server with ``./manage.py runserver`` run it as follows::

    ./manage.py runserver 0.0.0.0:8000

After it starts, go to your web browser and tell it to go to
http://www.yourowndomain.com:8000/. You should see your Django project
in action.

Usually you run the Django development server with ``./manage.py
runserver``, which is short for ``./manage.py runserver 8000``. This
tells the Django development server to listen for connections on port
8000. However, if you just specify "8000", it only listens for local
connections; a web browser running on the server machine itself will be
able to access the Django development server at
"http://localhost:8000/", but remote connections, from another machine,
won't work. We use "0.0.0.0:8000" instead, which asks the Django
development server to listen for network connections. Even better, if
your virtual server has IPv6 enabled, you can use this::

    ./manage.py runserver [::]:8000

This will cause Django to listen for connections on port 8000, both for
IPv4 and IPv6.

Next problem is that you can't possibly ask your users to use
http://www.yourowndomain.com:8000/, you have to get rid of the ":8000"
part. "http://www.yourowndomain.com/" is actually a synonym for
"http://www.yourowndomain.com:80/", so we need to tell Django to listen
on port 80 instead of 8000. This may or may not work::

    ./manage.py runserver 0.0.0.0:80

The problem is that port 80 is privileged. This means that normal users
aren't allowed to listen for connections on port 80; only the root user
is. So if you run the above command as as a normal user, Django will
probably tell you that you don't have permission to access that port.
Fix that problem by becoming root::

    sudo -s
    cd [your_project_directory]
    [activate your virtualenv]
    ./manage.py runserver 0.0.0.0:80

If this tells you that the port is already in use, it probably means
that a web server such as apache or nginx is already running on the
machine. Shut it down::

    service apache2 stop
    service nginx stop

When you finally get ``./manage.py runserver 0.0.0.0:80`` running, you
should, at last, be able to go to your web browser and reach your Django
project via http://www.yourowndomain.com/. Congratulations!

Of course, this is the wrong way to do it, but, as I told you, we are
experimenting. We now have a good starting place from which we'll go and
gradually start fixing things.
