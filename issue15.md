title:	MEDIA EXPORTER & BACKGROUND EXPORT QUEUE
state:	OPEN
author:	supreeththakur (Supreeth Singh Thakur )
labels:	
comments:	0
assignees:	
projects:	
milestone:	
issue-type:	
parent:	
sub-issues:	
sub-issues-completed:	
blocked-by:	
blocking:	
number:	15
--
MEDIA EXPORTER & BACKGROUND EXPORT QUEUE

Add a dedicated Media Exporter module to OneLyrics.

The purpose of this module is to allow users to continue creating and editing new lyric-video projects while previously created videos are being exported in the background.

The exporter must work as a persistent background export manager, not as a simple export button.

CORE WORKFLOW:

Create Video
→ Export
→ Add to Export Queue
→ Continue Working on Another Project
→ Background Export
→ Automatically Export Next Queued Video

The user should never need to manually start every export one by one.

==================================================
MEDIA EXPORTER
==================================================

Create a dedicated Media Exporter section inside OneLyrics.

The exporter should display:

CURRENTLY EXPORTING

- Video name
- Thumbnail
- Resolution
- FPS
- Codec
- Current progress
- Export speed
- Estimated remaining time
- Current file size
- Destination
- Pause
- Cancel

QUEUE

Show all pending export jobs.

Each queued item should display:

- Thumbnail
- Project/song name
- Resolution
- FPS
- Export format
- Estimated size
- Queue position
- Priority
- Status

COMPLETED

Show recently completed exports.

Display:

- Video name
- Output location
- Resolution
- Duration
- File size
- Completion time

FAILED

Show failed exports separately.

Display:

- Video name
- Reason for failure
- Retry button
- Remove button

==================================================
ADD TO QUEUE
==================================================

When the user selects:

Export

from the OneLyrics editor, do not immediately block the editor.

Show:

Export Video

[ Export Now ]

[ Add to Queue ]

If the user selects:

Add to Queue

the export job should immediately appear in the Media Exporter queue.

The user can then continue working on another project.

==================================================
BACKGROUND EXPORT
==================================================

Exports must run in the background.

While a video is exporting, the user must be able to:

- Create another project
- Edit another project
- Import another song
- Edit lyrics
- Synchronize lyrics
- Generate thumbnails
- Prepare another video
- Add additional exports to the queue

The export process must never freeze or block the main OneLyrics UI.

All heavy rendering/export operations must run outside the main UI thread.

==================================================
AUTOMATIC QUEUE PROCESSING
==================================================

The exporter must automatically process the queue.

Example:

CURRENT:
Paint The Town Red
Exporting 64%

QUEUE:

1. Galat Karam
2. Toxic
3. Softcore
4. West Coast

When Paint The Town Red finishes:

Automatically start:

Galat Karam

Then:

Toxic

Then:

Softcore

Then:

West Coast

The user must not click Export again.

==================================================
QUEUE MANAGEMENT
==================================================

Allow the user to:

- Add export
- Remove export
- Reorder exports
- Pause export
- Resume export
- Cancel export
- Retry failed export
- Clear completed exports
- Clear failed exports
- Clear queue

Allow drag-and-drop reordering.

Also provide:

Move to Top
Move to Bottom

==================================================
PRIORITY
==================================================

Each export job should support:

High
Normal
Low

Default:

Normal

Example:

High:
Client/urgent video

Normal:
Regular lyric videos

Low:
Test renders

The queue should automatically select the highest-priority eligible job.

If two jobs have the same priority, use queue order.

==================================================
EXPORT SETTINGS
==================================================

Every export job must store its own settings.

Supported:

Resolution:

1920x1080
3840x2160

FPS:

24
30
60

Aspect Ratio:

16:9

Format:

MP4

Video Codec:

H.264
H.265/HEVC where supported

Audio:

AAC

Allow the user to choose:

Quality preset
Bitrate
Audio bitrate
Frame rate
Resolution

Do not allow changing the settings of a job that is already actively exporting.

==================================================
OUTPUT LOCATION
==================================================

Allow:

Default export folder

and:

Custom export location per project.

Automatically generate clean filenames.

Example:

Artist - Song (Lyrics).mp4

Prevent accidental filename collisions.

If a file already exists:

Ask:

Replace
Rename
Cancel

Do not silently overwrite existing files.

==================================================
PROGRESS MONITORING
==================================================

Display real-time:

Progress:
64%

Elapsed:
03:21

Remaining:
01:47

Speed:
1.8x

Output:
2.4 GB

The progress must update smoothly without causing UI performance issues.

==================================================
PAUSE / RESUME
==================================================

Support pausing and resuming exports where the underlying rendering/export pipeline safely allows it.

If native export cannot safely pause an active operation:

Stop the current export cleanly and mark it resumable/retryable rather than corrupting the output.

Never leave partially corrupted files as completed exports.

==================================================
CANCEL
==================================================

When cancelling an active export:

Ask for confirmation.

Example:

Cancel export?

The current export will be stopped.

[Cancel Export]
[Continue Export]

Clean up temporary files safely.

==================================================
FAILED EXPORTS
==================================================

If an export fails:

Do not automatically delete the job.

Move it to:

FAILED

Show:

Export Failed

Reason:
Insufficient disk space

or:

Rendering error

or:

Source media unavailable

Provide:

[Retry]

Retry using the same settings.

==================================================
DISK SPACE MANAGEMENT
==================================================

Before starting an export:

Check available disk space.

If insufficient:

Do not start the export.

Show:

Not enough disk space.

Required:
18 GB

Available:
7 GB

Allow the user to change the destination.

==================================================
PROJECT INTEGRATION
==================================================

Every export job must remain linked to its original OneLyrics project.

Example:

Project:
Paint The Town Red

Export Job:
Paint The Town Red - 4K - 60 FPS

If the project is modified after an export job has already been queued:

Do not silently change the queued render.

The queue item must represent a snapshot/version of the project used when it was added.

If necessary, show:

Project has changed since this export was queued.

[Create New Export]
[Keep Existing Export]

==================================================
EXPORT SNAPSHOT
==================================================

When an export is added to the queue, store everything required for the render.

The export must not depend on the user continuing to keep the editor open.

Store/reference:

- Project version
- Timeline state
- Lyrics
- Typography settings
- Animations
- Background
- Effects
- Audio
- Rendering settings
- Output destination

The queued export should produce exactly the version that was added to the queue.

==================================================
APP RESTART RECOVERY
==================================================

The export queue must be persistent.

If OneLyrics is closed while exports are queued:

Save all queue information.

When OneLyrics opens again:

Restore:

QUEUED
FAILED
COMPLETED
CANCELLED

For an interrupted active export:

Mark it:

INTERRUPTED

Then provide:

[Resume]
[Retry]
[Remove]

Never falsely show an incomplete export as completed.

==================================================
BACKGROUND OPERATION
==================================================

The exporter should continue working while the user uses other parts of OneLyrics.

The user should be able to minimize the application while exports continue.

If technically supported by the macOS architecture, use appropriate background execution mechanisms so exports can continue reliably.

==================================================
SYSTEM RESOURCE MANAGEMENT
==================================================

The exporter must be resource-aware.

Monitor:

CPU usage
GPU usage
Memory usage
Disk usage
Thermal state where available

Default behavior:

One active export at a time.

Do not automatically start multiple heavy 4K exports simultaneously.

Allow future support for configurable export concurrency.

==================================================
EXPORT NOTIFICATIONS
==================================================

When an export finishes:

Show a native macOS notification.

Example:

Export Complete

Paint The Town Red has finished exporting.

[Show File]

When an export fails:

Show:

Export Failed

Paint The Town Red could not be exported.

[View Exporter]

Allow notifications to be disabled in settings.

==================================================
MEDIA EXPORTER DASHBOARD
==================================================

Create a clean dedicated interface:

MEDIA EXPORTER

Currently Exporting
-------------------

[Thumbnail]

Paint The Town Red

4K • 60 FPS • H.264

██████████████░░░░
72%

02:11 remaining

[Pause] [Cancel]


UP NEXT
--------

1. Galat Karam
   1080p • 30 FPS
   High

2. Toxic
   4K • 60 FPS
   Normal

3. Softcore
   1080p • 60 FPS
   Normal


COMPLETED
---------

✓ Skyfall
✓ 7 Years
✓ West Coast


FAILED
------

! Test Video
  Insufficient disk space
  [Retry]

==================================================
EDITOR INTEGRATION
==================================================

Add an export status indicator to the main OneLyrics application.

Example:

Exporting:
Paint The Town Red 72%

Clicking it opens:

Media Exporter

Also show a small global status indicator in the application.

Example:

Exporting 1
Queued 4
Completed 12

==================================================
MULTIPLE PROJECT WORKFLOW
==================================================

The final workflow should feel like this:

Project A
→ Finish
→ Add to Queue

Project B
→ Finish
→ Add to Queue

Project C
→ Finish
→ Add to Queue

Project D
→ Finish
→ Add to Queue

Meanwhile:

Media Exporter
→ Project A exporting
→ Project B waiting
→ Project C waiting
→ Project D waiting

When Project A finishes:

Project B automatically starts.

The user continues working without interruption.

==================================================
YOUTUBE INTEGRATION
==================================================

The Media Exporter must be designed to work with the OneLyrics YouTube Publishing system.

After an export completes successfully, allow the export job to trigger:

Export Complete
→ YouTube Publishing Queue

Optional setting:

[Automatically add completed exports to YouTube Publishing Queue]

This must only happen after the final video file has been successfully verified.

Do not upload incomplete or corrupted files.

==================================================
FINAL REQUIREMENT
==================================================

The Media Exporter should behave like a dedicated professional media encoding queue inside OneLyrics.

The user should be able to create multiple videos continuously while OneLyrics handles exporting them sequentially in the background.

The main editor must remain responsive throughout the entire process.

The user should never have to repeatedly click Export just to process the next video.
