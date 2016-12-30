Recovery
========

Why "recovery"?
---------------

Usually book chapters and blog posts dealing with what I'm dealing in
this chapter call it "backup and recovery". To me, backup is just a part
of recovery, it is only the first step towards recovery. This is why I
prefer to just use "recovery". It's not just a language issue, it's a
different way of thinking. When you deal with "backup and recovery", you
view them as two separate things. You might finish your backup and think
"I'm through with this, I'll deal with recovery if and when the time
comes". When we name it just "recovery", you understand that backup
isn't something isolated, and certainly it isn't the point. Backup on
its own is useless and pointless. Your customer doesn't care about
backup; they care about whether you are able to recover the system when
it breaks. In fact, they don't even care about that; they just care that
the system works, and they prefer to not know what you are doing behind
the scenes for it to work. One of the things you are doing behind the
scenes is to recover the system.

The most important thing about recovery is that it should be tested.
Once a year, or once in two years, you should switch off the server,
pretend it exploded, and recover on a new server. Without doing this,
you will not know if you can recover. Recovery plans contain all sorts
of silly errors. Maybe your backups are encrypted, and the decryption
key is only stored in the server itself, and you won't have it when you
need to recover. Maybe you don't backup some files that you think can be
recreated, and it turns that among them there are some valuable data
files. The thing is, you won't be able to know what you did wrong until
you test your recovery.

Untested recovery always takes way longer than you think. When you have
written down the recovery procedure and you have tested it, you may be
able to recovery within a couple of hours or even a few minutes, with
minimal stress. It can be part of your day-to-day work and not a huge
event. Without a written procedure, or with an untested procedure, you
will be sweating over your keyboard for a whole day or more, while your
customer will be frustrated. It's hard to imagine how much time you can
waste because you are getting a ``pg_restore`` option wrong until you
try it.

So, **think about recovery. Recovery starts with backup, continues with
the creation of a written restore procedure, and is mostly completed
when that procedure is tested.** Anything less than that is dangerous.

Where to backup
---------------

...

Do you think this is far-fetched? Code Spaces was a company that had its
code and data on Amazon Web Services. One day in 2014 an attacker
managed to get access to their account and demanded ransom. Negotiations
didn't go well and the attacker deleted all data. All backups.
Everything. The company was wiped out overnight. It ceased to exist.

Forget about two-factor authentication. Your phone might be stolen. Or
the employee who has access to the account _and_ has two
factor-authentication on his phone might go crazy and want to harm you.
Or _you_ might want to go crazy and hurt your customers. Or the whole
system, regardless its safety checks and everything, might have a bug
somewhere. Our experience of the last 20 years does not indicate that
systems are getting safer; on the contrary. Heartbleed showed how
vulnerable the whole Internet is; and the next heartbleed is just
waiting to be discovered.

The only way to be reasonably certain that your data is safe is if it's
offline, on a medium you can actually touch, disconnected from the
network.
