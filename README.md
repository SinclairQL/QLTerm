QLTerm Version 3.00b2 (10/6/2026)
=================================

Many bug fixes:

- Various ANSI rendering bugs fixed (e.g. inverse video)
- 'Log' and 'Transmit' menu options do work again
- File transfer progress on status line displayed spurious characters or strings of rubbish
- File transfer progress on status line now displays the full file name, including device and possible subdirectory name. For download, this is the path configured as download directory (default RAM2_). For upload, this is the full path entered by the user, or the default data directory set by DATA_USE when only the file name has been entered. Note that, during Ymodem file transfers, QLTerm will always send only the bare file name to the remote side, not including device and subdirectory name (as per Ymodem specification).
- File transfer progress now also displays throughput
- BEL configuration option had no effect
- Using 'Local echo' option could cause a race condition on display
- Under certain circumstances, QLTerm could lock up after displaying more than 32K bytes
- Enhancement: During file transfers, QLTerm may optionally disable serial port TRAnslations
- Enhancement: The Connect command remembers the last phone number or host name you entered so you can re-connect with just ENTER, or clear the entry using arrow up/down keys.

QLTerm Version 3.00b1 (22/5/2026)
=================================

A major overhaul of the code after nearly 10 years. You might wonder why one would still spend many hours of spare time on a 68K assembly project which started almost 40 years ago. After all, we already have had better terminal programs like QTPI for decades?

Well, first of all, I do like QTPI and its extensive features. However, it’s now 2026 and the communication world looks very different from the ‘80s or ‘90s. Even in the QL-like world there have been developments in the past ten years. One of them is the appearance of QL replacements like the Q68 and QIMSI Gold, supporting serial port speeds of over 100 kilobits to even megabits per second using QIMSI Gold’s USB port. With these speeds, the bottleneck is no longer the serial port itself, but the software used to transfer files. I would like to make QLTerm the fastest QL communication program in the world!

So, QLTerm will continue to support serial communications, despite the demise of traditional RS232-ports on modern hardware.
Another thing is TCP/IP support, mainly on emulated platforms, but also on the Q68. QLTerm’s flexibility allowed it to be used as a Telnet client with minor adaptions, but there were still some issues with the non-transparent nature of the protocol. This version now offers full Telnet support, including automatic signalling of terminal type and size to the host.
(Note: if you’re tempted to say ‘Telnet is outdated and insecure!’, I would fully agree with you. But wouldn’t it be great to be able to use your old QL software to connect to your own Linux computer? And when you need security, the uqlx/sqlux emulator allows you to pipe your I/O through SSH, if you’re running Linux.

As mentioned, this is still a beta version. Any bugs and feature requests can be reported at https://github.com/SinclairQL/QLTerm/issues.

So, what's new?
---------------

- QLTerm is now configured using the freely available MenuConfig utility, available from https://sinclairql.net/djw/config/index.html, with many more configuration options available. Do not use the old qltconfig_bas program to configure this and newer versions.

- Size and position of QLTerm’s window is now configurable. You can specify the position of the top left corner of QLTerm’s window in pixels and its size in characters. The minimum and maximum width are 80 and 255 characters respectively, and the minimum and maximum terminal length are 24 and 127 characters. 
Each character is 6 pixels across and 10 pixels down, so a window configured for 40 rows of 100 characters will occupy 604 pixels across (100\*6 plus 4 pixels for border) and 414 pixels down (40\*10 plus status line plus 4 pixels for border) and thus will fit into a screen of 640 x 480 pixels. If you have an 800 x 600 screen resolution, you can configure a maximum width of 132 columns and 58 rows.
Note: You must allow for one extra row for the status and command line plus border (12 pixels). If the configured window is too large for the current screen size, QLTerm will revert to the standard terminal window size, which is 24 rows of 80 characters.

- Dropped support of Miracle Systems Modapter and QModem. I cannot imagine that these legacy devices are still in use anywhere in the world, and I don’t have them in my possession anymore, so I cannot test the functionality anyway. The code to drive them required translation for every character to be sent, causing inefficient I/O especially for file transfers.

- Instead, I have added support for Telnet using the TCP device, which is present on modern QL emulators such as QPC2, QEmulator and sQLux, so you don’t longer need the telnet.bas S\*BASIC procedure to connect to a Telnet server. There are actually two modes for using TCP/IP: Raw TCP mode and Telnet mode (selectable using the (I)nterface command).
  - Telnet mode can be used to connect to a true Telnet server, as used by Linux systems and some BBS systems such as MBSE and DOS BB's behind NetFoss. The protocol allows for information about the terminal, such as window size and graphic capabilities, to be negotiated between client and server. The protocol uses escape sequences, introduced by the IAC character ($FF), so is by itself not transparent for 8-bit file transfers. However, QLTerm allows for the IAC character in the data stream to be escaped by the double IAC sequence, so X/Ymodem file transfers are still possible over Telnet sessions if the server supports it.
  - Raw TCP is a pure 8-bit TCP connection to a server. It can be used to connect to servers that do support logins via TCP/IP, but are not Telnet-compliant. Use this option if file transfers over Telnet fail. This protocol is potentially faster than Telnet, but doesn't exchange any information about terminal capabilities that Telnet servers expect, so it might not be possible to successfully connect to a Telnet server.

- To connect to a TCP/IP or Telnet server, use the (C)onnect command (formerly (C)all), and specify the host name or IP address. If the port is different from the standard Telnet port (23), specify the port number following the address separated by a colon, e.g. 'mybbs.com:12345'.

- For serial ports, the available baud rates have been extended to include 38400, 57600, and 115200 bps (replacing the former 75, 12M75, 12S75 and 12P75 options) for hardware with fast serial ports. The baud rate can also be set to NONE (which means ‘do not change it’). This allows you to specify the baud rate outside QLTerm (using the BASIC BAUD command) for non-standard baud rates. \
The 12H75 option remains available for users of the Hermes replacement IPC chip, allowing for a split receive/transmit rate of 1200/75 bps (anyone still using it?).

- The Parity options (Even, Odd, Mark, Space) have been dropped. If you still need to communicate with legacy systems which don’t use 8N1 (8-bit, no parity), you can configure a custom communication device such as ‘SER2E’ which (hopefully!) handles the parity. You can also use this option to use QLTerm with alternative serial ports, such as SER3 or SER4.

- Fixed rendition of some ANSI CSI sequences (in particular, private sequences such as ‘ESC \[ ? ). Also, a TAB character (ASCII 9) now moves to the next column which is a multiple of 8.

- The ENTER key can now be configured in the (O)ptions menu to send either a CR or LF character, or both. Default is CR (as in older versions), but may be changed using menuconfig.

- The BACKSPACE key (CTRL-Left arrow on the QL keyboard) can now be configured to send either the Backspace character (8) or DEL (127). The latter is default.

- QLTerm now accepts up to three channels when started with EX/EW. The first channel will be used for input, the second for logging (if enabled) and the third for output. This is compatible with QTPI’s piped mode. \
Unlike QTPI, you can still use QLTerm started with one channel (for both send and receive) or two (for separate send and receive channels).

- Support for XMODEM-1K, YMODEM and YMODEM-G file transfer protocols:

  - XMODEM-1K is like XMODEM, but uses data blocks of 1 Kbyte rather than 128 bytes, thus reducing overhead.

  - YMODEM also uses data blocks of 1 Kbyte, but adds a header block containing the file name, length, and update date. This allows for multiple files to be transferred in one batch and doesn’t require you to type in the file name when downloading. In addition, the file update date and true length are preserved, unlike XMODEM which adds up to 127 bytes of additional data to the file. YMODEM is therefore the preferred protocol for reliable file transfers.

  - YMODEM-G is like YMODEM, but sends all data blocks at once, without waiting for each block to be acknowledged by the receiver. It’s the fastest protocol, but must be used with caution. Since the receiver cannot ask for a corrupted or missed data block to be re-sent, YMODEM-G may only be used when the connection between sender and receiver is reliable, and the receiver is capable of receiving the whole file uninterrupted. The connection may be a serial link between two computers, a link between two modems with V.42bis error correction, or a TCP/IP link. The receiver must be able to process the file fast enough to handle the line speed – on QL-like hardware this usually means it must be written to RAM-disk first before being copied it to storage like floppy disk or SD-card. Writing directly to the latter devices usually causes delays in processing, leading to failed transfers. Even when using RAM-disk and accelerated QL-like hardware such as a (Super) Gold Card, Q68 or QIMSI Gold, the receiving end might not be fast enough to handle transfer speeds of more than 100 kbps. If such transfers fail, you must not use the G option, lower the link speed or use a larger download buffer which allows for the whole file to be received in RAM before being written to disk. Note that an emulated QL or SMSQ/E environment running on a PC is usually fast enough to handle YMODEM-G when receiving.

  - You might wonder why QLTerm still doesn’t support ZMODEM. While I would like to include this fast and robust protocol, implementing this as internal protocol would be a bit like re-inventing the wheel since the C source code of ZMODEM has been around for some 40-odd years. Implementing it as external protocol would be a better option for the near future, if I can get it compiled by a decent C compiler and, more important, get it to work efficiently on serial and TCP links which are 100 to 1000 times as fast as in 1986. Tests with QTPI on those links have shown that sending files from QL-like hardware to a PC is usually no problem, but the other way round often failed due to the QL not being able to handle the continual data stream from the PC. Changing the ZMODEM frame size to 1K would solve this, but that would make it just as slow as YMODEM without G option. A better solution is to use windowing (limiting the number of in-transit frames), which also solves the problem of transfers failing due to excessive buffering by TCP- and serial devices on some platforms. Unfortunately, many ZMODEM implementations (including QTPI’s) do not support this option. \
  In any case, ZMODEM support remains on my to-do list, but no guarantee when (or even if) it will be ready…

  - Added support for the QDOS header protocol used by emulators such as QPC2 and Qemulator. These store the extra header information, required for EXECutable QDOS files, in the first 30 bytes of the file stored on DOS or Windows-like file systems. QLTerm will add the header information to uploaded files if the file type is nonzero (meaning an executable or relocatable binary file), and sets the header information accordingly on downloaded files when they contain this information in the first 30 bytes. It is therefore safe to transfer these files to and from a PC, using a PC file transfer program at the other end to store them on a DOS drive used by QPC2 or Qemulator. \
  Note that the header information doesn’t include the file length and update date. If you want this information to be preserved, use the YMODEM protocol, not XMODEM.

- Note that the QLTerm manual hasn't been updated yet, so still applies to the old v2.x versions.
