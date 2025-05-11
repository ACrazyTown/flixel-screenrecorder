package flixel.addons.plugin.screenrecorder;

import flixel.FlxBasic;
import flixel.FlxG;
import lime.graphics.Image;
import sys.io.Process;

class FlxScreenRecorder extends FlxBasic
{
    var process:Process;
    var recording:Bool = false;

    var width:Int;
    var height:Int;
    var framerate:Float;

    var ffmpegPath:String = "ffmpeg";

    public function new(?width:Int, ?height:Int, ?framerate:Float)
    {
        super();

        this.width = width ?? FlxG.stage.window.width;
        this.height = height ?? FlxG.stage.window.height;
        this.framerate = framerate ?? FlxG.stage.window.frameRate;

        getFFMPEGPath();

        FlxG.stage.window.application.onExit.add((_) ->
        {
            if (recording)
            {
                stop();
            }
        });
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (recording)
        {
            captureFrame();
        }
    }

    public function start(codec:VideoCodec = H264, crf:Int):Void
    {
        try {
            process = new Process(ffmpegPath, 
            [
                "-y",
                "-f",
                "rawvideo",
                "-pix_fmt",
                "rgba",
                "-s",
                '${width}x${height}',
                "-r",
                '$framerate',
                "-i",
                "-",
                "-c:v",
                codec,
                "-crf", 
                '$crf',
                'flxscreenrecorder_output.${getCodecExtension(codec)}'
            ], false);

            // process = new Process('ffmpeg -y -f rawvideo -pix_fmt rgba -s ${width}x${height} -r $framerate -i - -c:v $codec -crf $crf flxscreenrecorder_output.${getCodecExtension(codec)}', null, false);
        }
        catch (e)
        {
            FlxG.log.error('[FlxScreenRecorder] Failed to open FFMPEG: ${e.message}');
        }

        if (process != null)
            FlxG.log.add("Initialized successfully?");

        recording = true;
        // captureFrame();
    }

    public function stop():Void
    {
        // trace(process.stdout.readLine());
        process?.close();
        recording = false;
    }

    function captureFrame():Void
    {
        if (process != null)
        {
            // FlxG.log.add("capture!" + FlxG.game.ticks);
            var frame:Image = FlxG.stage.window.readPixels();
            process.stdin.write(frame.buffer.data.buffer);
        }
    }

    function getFFMPEGPath():Void
    {
        // Sys.command(Sys.systemName() == "Windows" ? "where" : "which", ["ffmpeg"]);
    }

    function getCodecExtension(codec:VideoCodec):String
    {
        return switch (codec)
        {
            case H264, H265: "mp4";
            default: "";
        }
    }
}

enum abstract VideoCodec(String) from String to String
{
    var H264 = "libx264";
    var H265 = "libx265";
}
