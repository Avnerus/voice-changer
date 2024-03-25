import socketio

from sio.MMVC_Namespace import MMVC_Namespace
from voice_changer.VoiceChangerManager import VoiceChangerManager

from gst.Streamer import MMVC_GSTStreamer 


class MMVC_SocketIOServer:
    _instance: socketio.AsyncServer | None = None
    
    @classmethod
    def get_instance(cls, voiceChangerManager: VoiceChangerManager):
        if cls._instance is None:
            streamer = MMVC_GSTStreamer()
            sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")
            namespace = MMVC_Namespace.get_instance(voiceChangerManager, streamer)
            sio.register_namespace(namespace)
            cls._instance = sio
            return cls._instance

        return cls._instance
