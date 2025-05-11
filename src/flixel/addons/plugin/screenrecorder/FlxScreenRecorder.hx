package flixel.addons.plugin.screenrecorder;

import lime.graphics.opengl.GL;
import haxe.io.Bytes;
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

    var frameBuffer:Bytes;

    /**
     * Creates a new FlxScreenRecorder instance.
     * @param ffmpegPath Optional; use this to provide a custom path to FFMPEG.
     * If left blank, FlxScreenRecorder will automatically search for an installation of FFMPEG.
     */
    public function new(?ffmpegPath:String)
    {
        super();

        this.ffmpegPath = ffmpegPath ?? getFFMPEGPath();
        frameBuffer = Bytes.alloc(width * height * 4);

        FlxG.stage.window.application.onExit.add(onLimeApplicationExit);
    }

    @:inheritDoc(FlxBasic.destroy)
    override function destroy():Void
    {
        super.destroy();

        if (recording)
            stop();

        FlxG.stage.window.application.onExit.remove(onLimeApplicationExit);

        frameBuffer = null;
    }

    /**
     * Starts the recording the 
     * @param params 
     */
    public function start(params:FlxScreenRecordParams):Void
    {
        var width:Int = params.width ?? FlxG.stage.window.width;
        var height:Int = params.height ?? FlxG.stage.window.height;

        var framerate:Float = params.framerate ?? FlxG.stage.window.frameRate;
        var codec:VideoCodec = params.videoCodec ?? H264;
        var crf:Int = params.crf ?? 23;

        var output:String = params.output ?? 'flxscreenrecorder_${DateTools.format(Date.now(), "%Y%m%d%H%M%S")}';
        output += getCodecExtension(codec);

        try {
            process = new Process(ffmpegPath, 
            [
                "-y",                                                  // Overwrite file
                "-f", "rawvideo",                                      // Set input file format to be raw video
                "-pix_fmt", "rgba",                                    // Set pixel format to be RGBA
                "-s", '${width}x${height}',                            // Set the input size
                "-r", '$framerate',                                    // Set the input framerate
                "-i", "-",                                             // Set the input to be stdin
                "-c:v", codec,                                         // Set the video codec
                "-crf", '$crf',                                        // Set the crf quality
                'flxscreenrecorder_output.${getCodecExtension(codec)}' // Set output filename
            ], false);
        }
        catch (e)
        {
            FlxG.log.error('[FlxScreenRecorder] Failed to open FFMPEG: ${e.message}');
        }

        recording = true;
    }

    public function captureFrame():Void
    {
        if (recording && process != null)
        {
            FlxG.stage.window.context.gl.readPixels(0, 0, width, height, GL.RGBA, GL.UNSIGNED_BYTE, frameBuffer);
            process.stdin.write(frameBuffer);
        }
    }

    public function stop():Void
    {
        // trace(process.stdout.readLine());
        process?.close();
        process = null;

        recording = false;
    }

    function getFFMPEGPath():String
    {
        // Sys.command(Sys.systemName() == "Windows" ? "where" : "which", ["ffmpeg"]);
        var command:String = Sys.systemName() == "Windows" ? "where" : "which";
        var ffmpegFinder:Process = new Process(command, ["ffmpeg"]);
        var code:Int = ffmpegFinder.exitCode();

        if (code != 0)
        {
            // 
        }

        return null;
    }

    function getCodecExtension(codec:VideoCodec):String
    {
        return switch (codec)
        {
            case H264, H265: "mp4";
            default: "";
        }
    }
    
    function onLimeApplicationExit(code:Int):Void
    {
        trace("exiting");
        if (recording)
            stop();
    }
}

enum abstract VideoCodec(String) from String to String
{
    var H264 = "libx264";
    var H265 = "libx265";
}

typedef FlxScreenRecordParams =
{
    ?width:Int,
    ?height:Int,
    
    ?framerate:Float,
    ?videoCodec:VideoCodec,
    ?crf:Int,

    ?output:String
}
