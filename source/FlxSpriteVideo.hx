#if web
import openfl.net.NetConnection;
import openfl.net.NetStream;
import openfl.events.NetStatusEvent;
import openfl.media.Video;
#else
import openfl.events.Event;
import vlc.VlcBitmap;
#end
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxG;

// deprecated, please find a better way to do this
// i beg of you don't look at this garbage code
class FlxSpriteVideo extends FlxSprite {
	#if VIDEOS_ALLOWED
    
	#if desktop
    public var video:FlxVideo;
	#end

    var firstFetch:Bool = true;
    var fetchTimer:Int = 0;
    var repeats:Int = 0;

    public function stop() {
		FlxVideo.vlcBitmap.stop();

		// Clean player, just in case!
		FlxVideo.vlcBitmap.dispose();

		if (FlxG.game.contains(FlxVideo.vlcBitmap)) FlxG.game.removeChild(FlxVideo.vlcBitmap);
		if (video.finishCallback != null) video.finishCallback();

        video.kill();
    }

	public function new(x:Float, y:Float, name:String, looping:Bool = false, repeats:Int = -1) {
		super(x, y);

		#if desktop
		// by Polybius, check out PolyEngine! https://github.com/polybiusproxy/PolyEngine

        repeats = (looping ? repeats : 0);

        video = new FlxVideo(name, false, repeats);

        FlxVideo.vlcBitmap.visible = false;
		#end
	}

    override function update(elapsed:Float) {
        fetchTimer ++;
        if (firstFetch || fetchTimer % Math.round(ClientPrefs.framerate / 30) == 0)
        {
            if (FlxVideo.vlcBitmap != null) {
                if (pixels != FlxVideo.vlcBitmap.bitmapData) {
                    if (FlxVideo.vlcBitmap.bitmapData != null) {
                        //trace ("so it's there yo");
                        pixels = FlxVideo.vlcBitmap.bitmapData;
                        firstFetch = false;
                    }
                }
            }
        }
        
        super.update(elapsed);
    }  
    #end
}