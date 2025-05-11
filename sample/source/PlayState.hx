package;

import lime.system.System;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.FlxState;
import flixel.addons.plugin.screenrecorder.FlxScreenRecorder;

class PlayState extends FlxState
{
	var recorder:FlxScreenRecorder;

	var text:FlxText;
	var timer:Float;

	override public function create()
	{
		super.create();

		FlxG.autoPause = false;
		FlxG.fixedTimestep = false;

		text = new FlxText(0, 0, 0, "0", 24);
		text.screenCenter();
		add(text);

		recorder = new FlxScreenRecorder();
		recorder.start(H264, 30);
		add(recorder);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		timer += elapsed;
		text.text = '$timer';

		if (timer >= 5)
		{
			recorder.stop();
			FlxG.stage.window.alert("Saved recording.", "flixel-screenrecorder-sample");
			System.exit(0);
		}
	}
}
