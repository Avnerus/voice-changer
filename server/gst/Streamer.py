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
        pipeline = Gst.Pipeline()

        # Create appsrc element
        self.appsrc = Gst.ElementFactory.make('appsrc', 'audio_source')
        self.appsrc.set_property('format', Gst.Format.TIME)

        caps = Gst.Caps.from_string("audio/x-raw,format=S16BE,layout=interleaved,rate=48000,channels=1,payload=96")
        self.appsrc.set_property('caps', caps)

        pipeline.add(self.appsrc)

        audio_convert = Gst.ElementFactory.make('audioconvert', 'audio_convert')   
        pipeline.add(audio_convert)

        # Create RTP audio payloader
        rtp_pay = Gst.ElementFactory.make('rtpL16pay', 'rtp_pay')
        pipeline.add(rtp_pay)

        # Link appsrc with RTP payloader
        self.appsrc.link(rtp_pay)

        # Create UDP sink
        udp_sink = Gst.ElementFactory.make('udpsink', 'udp_sink')

        # Set the host and port to send to
        udp_sink.set_property('host', '192.168.1.209')
        udp_sink.set_property('port', 5000)

        pipeline.add(udp_sink)

        # Link RTP payloader with UDP sink
        rtp_pay.link(udp_sink)

        # Start playing
        ret = pipeline.set_state(Gst.State.PLAYING)

        print("Init GST Streamer: Playing, status: {}".format(ret))

    async def push(self, data):
        # Push data into the appsrc
        print("Pushing {}".format(len(data)))
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.appsrc.emit, 'push-buffer', Gst.Buffer.new_wrapped(data))
