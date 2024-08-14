import asyncio
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst
import os
import numpy as np
os.environ["GST_DEBUG"] = "3"

class MMVC_GSTStreamer:
    def __init__(self):
        print("Init GST Streamer: Starting")

        # Initialize GStreamer
        Gst.init(None)

        # Create the pipeline
        self.pipe = Gst.parse_launch( 'webrtcsink signaller::uri="wss://puppetvoice.aalto.fi:8443" name=ws meta="meta,name=puppet" audio-caps="audio/x-opus" appsrc name=voice ! audioconvert ! ws.')
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

        asyncio.create_task(self.push_zeroes())

    async def push(self, data):
        # Push data into the appsrc
        print("Pushing {}".format(len(data)))
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.appsrc.emit, 'push-buffer', Gst.Buffer.new_wrapped(data))

    async def push_zeroes(self):
        # Push some zeroes to force the pipeline to start and connect to the signalling server
        for i in range(10):
            await self.push(np.zeros(4096).astype(np.int16))
