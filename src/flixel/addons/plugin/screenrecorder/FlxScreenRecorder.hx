package flixel.addons.plugin.screenrecorder;

import flixel.FlxBasic;
import flixel.FlxG;
import haxe.io.Bytes;
import lime.graphics.Image;
import lime.utils.UInt8Array;
import sys.io.Process;

class FlxScreenRecorder extends FlxBasic
{
    var process:Process;
    var recording:Bool = false;

    var width:Int;
    var height:Int;

    var ffmpegPath:String = "ffmpeg";

    var canWork:Bool = true;

    var frameBuffer:Bytes;

    var hardware:Bool;

    /**
     * Creates a new FlxScreenRecorder instance.
     * @param ffmpegPath Optional; use this to provide a custom path to FFMPEG.
     * If left blank, FlxScreenRecorder will automatically search for an installation of FFMPEG.
     */
    public function new(?ffmpegPath:String)
    {
        super();

        this.ffmpegPath = ffmpegPath ?? getFFMPEGPath();
        if (this.ffmpegPath == null)
        {
            FlxG.log.error("[FlxScreenRecorder] Could not find an installation of FFMPEG!");
            canWork = false;
        }

        hardware = FlxG.stage.window.context.attributes.hardware;
            //frameBuffer = Bytes.alloc(width * height * 4);

        trace(frameBuffer);

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
        if (!canWork)
            return;

        width = params.width ?? FlxG.stage.window.width;
        height = params.height ?? FlxG.stage.window.height;

        var framerate:Float = params.framerate ?? FlxG.stage.window.frameRate;
        var codec:VideoCodec = params.videoCodec ?? H264;
        var crf:Int = params.crf ?? 23;

        var output:String = params.output ?? 'flxscreenrecorder_${DateTools.format(Date.now(), "%Y%m%d%H%M%S")}';

        try {
            var args:Array<String> = 
            [
                "-y",                                                  // Overwrite file
                "-f", "rawvideo",                                      // Set input file format to be raw video
                "-pix_fmt", "rgba",                                    // Set pixel format to be RGBA
                "-s", '${width}x${height}',                            // Set the input size
                "-r", '$framerate',                                    // Set the input framerate
                "-i", "-",                                             // Set the input to be stdin
            ];

            // glReadPixels() returns an upside down image, instead of correcting it
            // on the Haxe side we'll just tell FFMPEG to accept it properly
            if (hardware)
            {
                args.push("-vf");
                args.push("vflip");
            }

            // Set codec & quality
            args.push("-c:v");
            args.push(codec);
            args.push("-crf");
            args.push(Std.string(crf));

            // Set output file
            args.push('$output.${getCodecExtension(codec)}');

            process = new Process(ffmpegPath, args, false);

        }
        catch (e)
        {
            FlxG.log.error('[FlxScreenRecorder] Failed to open FFMPEG: ${e.message}');
        }

        if (hardware && frameBuffer == null)
            frameBuffer = Bytes.alloc(width * height * 4);

        recording = true;
    }

    public function captureFrame():Void
    {
        if (!canWork)
            return;

        if (recording && process != null)
        {
            if (hardware)
            {
                var gl = FlxG.stage.window.context.gl;
                gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, frameBuffer);
                process.stdin.write(frameBuffer);
            }
            else
            {
                process.stdin.write(FlxG.stage.window.readPixels().buffer.data.buffer);
            }
        }
    }

    public function stop():Void
    {
        if (!canWork)
            return;

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
        var globalFFMPEGPath:Null<String> = null;

        try {
            globalFFMPEGPath = ffmpegFinder.stdout.readLine();
        } 
        catch (e) {}
        
        var code:Int = ffmpegFinder.exitCode();

        if (code == 0 && globalFFMPEGPath != null)
        {
            return globalFFMPEGPath;
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
