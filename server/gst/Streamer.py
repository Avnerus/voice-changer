import asyncio
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst
import os
os.environ["GST_DEBUG"] = "3"

class MMVC_GSTStreamer:
    def __init__(self):
        print("Init GST Streamer: Starting")

        # Initialize GStreamer
        Gst.init(None)

        # Create the pipeline
        self.pipe = Gst.parse_launch(
            'webrtcsink signaller::uri="ws://127.0.0.1:8000" name=ws meta="meta,name=puppet" audio-caps="audio/x-opus" appsrc name=voice ! audioconvert ! ws.')
        self.webrtcsink = self.pipe.get_by_name('ws')
        self.signaller = self.webrtcsink.get_property('signaller')
        self.appsrc = self.pipe.get_by_name('voice')
        self.appsrc.set_property('format', Gst.Format.TIME)
        self.appsrc.set_property("is-live", True)
        caps = Gst.Caps.from_string("audio/x-raw,format=S16BE,layout=interleaved,rate=48000,channels=1,payload=96")
        self.appsrc.set_property('caps', caps)

        # Start playing
        ret = self.pipe.set_state(Gst.State.PLAYING)
        print("Init GST Streamer: Playing, status: {}".format(ret))

    async def push(self, data):
        # Push data into the appsrc
        print("Pushing {}".format(len(data)))
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.appsrc.emit, 'push-buffer', Gst.Buffer.new_wrapped(data))
