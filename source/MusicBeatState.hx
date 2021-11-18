package;

import Conductor.BPMChangeEvent;
import flixel.FlxG;
import flixel.addons.ui.FlxUIState;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxState;
import flixel.FlxBasic;
import flixel.group.FlxGroup;

typedef ControlCallback = {
	var input:String;
	@:optional var debug:Bool;
	@:optional var name:String;
	@:optional var keys:Array<String>; // only used if multiple keys should give this callback
	@:optional var useMultipleKeys:Bool;
	@:optional var isSpecialKey:Bool;
	@:optional var specialInput:SpecialInput;
	var callback:Dynamic->Void;
}

typedef SpecialInput = {
	// Using typedef in case I want to build onto this in the future
	var type:String;
}

class MusicBeatState extends FlxUIState {
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var controls(get, never):Controls;

	var keyReleaseCallbacks:Array<ControlCallback>;
	var   keyPressCallbacks:Array<ControlCallback>;
	var    keyDownCallbacks:Array<ControlCallback>;
	var      keyUpCallbacks:Array<ControlCallback>;

	inline function get_controls():Controls 
		return PlayerSettings.player1.controls;

	#if mobile
	var screenTappedCallbacks:Array<ControlCallback>;
	public function onScreenTapped(callback:Dynamic->Void, name:String = "Unnamed Input", debug:Bool = false) {
		if (screenTappedCallbacks == null) screenTappedCallbacks = [];
		screenTappedCallbacks.push({input: "_TOUCH", name:name, callback:callback, debug:debug});
	}
	#end

	public function onKeyPress(input:String, callback:Dynamic->Void, name:String = "Unnamed Input", keys:Array<String> = null, useMultipleKeys:Bool = false, debug:Bool = false, ?isSpecialKey:Bool = false, ?specialInputType:String = "keys") {
		if (keyPressCallbacks == null) 
			keyPressCallbacks = [];
		keyPressCallbacks.push({input:input, keys:keys, name:name, useMultipleKeys:useMultipleKeys, callback:callback, debug:debug, isSpecialKey:isSpecialKey, specialInput: {type: specialInputType}});
	}

	public function onKeyRelease(input:String, callback:Dynamic->Void, name:String = "Unnamed Input", keys:Array<String> = null, useMultipleKeys:Bool = false, debug:Bool = false, ?isSpecialKey:Bool = false) {
		if (keyReleaseCallbacks == null) 
			keyReleaseCallbacks = [];
		keyReleaseCallbacks.push({input:input, keys:keys, name:name, useMultipleKeys:useMultipleKeys, callback:callback, debug:debug, isSpecialKey:isSpecialKey});
	}

	public function ifKeyDown(input:String, callback:Dynamic->Void, name:String = "Unnamed Input", keys:Array<String> = null, useMultipleKeys:Bool = false, debug:Bool = false, ?isSpecialKey:Bool = false) {
		if (keyDownCallbacks == null) 
			keyDownCallbacks = [];
		keyDownCallbacks.push({input:input, keys:keys, name:name, useMultipleKeys:useMultipleKeys, callback:callback, debug:debug, isSpecialKey:isSpecialKey});
	}

	public function ifKeyUp(input:String, callback:Dynamic->Void, name:String = "Unnamed Input", keys:Array<String> = null, useMultipleKeys:Bool = false, debug:Bool = false, ?isSpecialKey:Bool = false) {
		if (keyUpCallbacks == null) 
			keyUpCallbacks = [];
		keyUpCallbacks.push({input:input, keys:keys, name:name, useMultipleKeys:useMultipleKeys, callback:callback, debug:debug, isSpecialKey:isSpecialKey});
	}

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;

		#if mobile
		screenTappedCallbacks = [];
		#end

		keyPressCallbacks = [];
		keyReleaseCallbacks = [];
		keyDownCallbacks = [];
		keyUpCallbacks = [];
		super.create();

		// Custom made Trans out
		if(!skip) {
			openSubState(new CustomFadeTransition(1, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
	}
	
	#if (VIDEOS_ALLOWED && windows)
	override public function onFocus():Void {
		FlxVideo.onFocus();
		super.onFocus();
	}
	
	override public function onFocusLost():Void {
		FlxVideo.onFocusLost();
		super.onFocusLost();
	}
	#end

	override function update(elapsed:Float) {
		var oldStep:Int = curStep;

		updateInputs();
		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);
	}

	private function getInputJustPressed(input:String, isSpecialInput:Bool = false, ?specialInputType:String = "keys"):Bool {
		if (!isSpecialInput) {
			return Reflect.getProperty(controls, input);
		} else {
			switch (specialInputType.toLowerCase()) {
				case "keys":
					return Reflect.getProperty(FlxG.keys.justPressed, input);
				case "gamepad":
					if (FlxG.gamepads.lastActive != null)
					return Reflect.getProperty(FlxG.gamepads.lastActive.justPressed, input);
					else return false;
				default:
					return false;
			}
		}
	}

	private function getInputJustReleased(input:String, isSpecialKey:Bool = false, ?specialInputType:String = "keys"):Bool {
		if (!isSpecialKey) {
			return false;
		} else {
			switch (specialInputType.toLowerCase()) {
				case "keys":
					return Reflect.getProperty(FlxG.keys.justReleased, input);
				case "gamepad":
					if (FlxG.gamepads.lastActive != null)
					return Reflect.getProperty(FlxG.gamepads.lastActive.justReleased, input);
					else return false;
				default:
					return false;
			}
		}
	}

	private function getInputDown(input:String, isSpecialKey:Bool = false, ?specialInputType:String = "keys"):Bool {
		if (!isSpecialKey) {
			return Reflect.getProperty(controls, input);
		} else {
			switch (specialInputType.toLowerCase()) {
				case "keys":
					return Reflect.getProperty(FlxG.keys.pressed, input);
				case "gamepad":
					if (FlxG.gamepads.lastActive != null)
					return Reflect.getProperty(FlxG.gamepads.lastActive.pressed, input);
					else return false;
				default:
					return false;
			}
		}
	}

	private function updateInputs():Void {
		#if mobile 
		updateScreenTaps(); 
		#end

		updateReleases();
		updatePresses();
		updateKeyUp();
		updateKeyDown();
	}

	private function updatePresses() {
		// KEY PRESS
		if (keyPressCallbacks == null) return;
		for (i in keyPressCallbacks) {
			if (!i.useMultipleKeys || i.keys == null) {
				var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
				var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
				var controlActive:Bool = getInputJustPressed(i.input, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
				if (controlActive) {
					if (i.debug != null) if (i.debug) trace("Key press input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(null); // Do the callback, but throw null because no data to be sent
				}
			} else {
				// The case in which i actually use the multiple keys BS (aka never)
				var keysActive:Map<String, Bool> = new Map<String, Bool>();
				var doCallback:Bool = false;

				for (j in i.keys) {
					var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
					var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
					var controlActive:Bool = getInputJustPressed(j, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
					if (controlActive && !doCallback) doCallback = true;
					if (controlActive) keysActive.set(j, controlActive);
				}

				if (doCallback) {
					/* In this scenario, we do the callback AND throw the active keys through.
					   This can be useful if you want to condense the inputs into one function rather than multiple.
					   This is not recommended, but do what you please. */
					if (i.debug != null) if (i.debug) trace("Key press input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(keysActive);
				}
			}
		}
	}

	#if mobile
	private function updateScreenTaps() {
		// SCREEN TAP
		if (screenTappedCallbacks == null) return;
		for (i in screenTappedCallbacks) {
			var touches:Array<FlxTouch> = FlxG.touches.touchStarted();
			var controlActive = if (touches.length != 0) 1 else 0;
			if (controlActive) {
				if (i.debug != null) if (i.debug) trace("Screen tap input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
				i.callback(touches); // Do the callback, but throw null because no data to be sent
			}
		}
	}
	#end

	// DOES NOT FUNCTION WITH CONTROLS.
	private function updateReleases() {
		// KEY RELEASE
		if (keyReleaseCallbacks == null) return;
		for (i in keyReleaseCallbacks) {
			if (!i.useMultipleKeys || i.keys == null) {
				var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
				var specialInputData:SpecialInput = (i.specialInput != null ? i.specialInput : null);
				var controlActive:Bool = getInputJustReleased(i.input, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
				if (controlActive) {
					if (i.debug != null) if (i.debug) trace("Key release input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(null); // Do the callback, but throw null because no data to be sent
				}
			} else {
				// The case in which i actually use the multiple keys BS (aka never)
				var keysActive:Map<String, Bool> = new Map<String, Bool>();
				var doCallback:Bool = false;

				for (j in i.keys) {
					var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
					var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
					var controlActive:Bool = getInputJustReleased(j, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
					if (controlActive && !doCallback) doCallback = true;
					if (controlActive) keysActive.set(j, controlActive);
				}

				if (doCallback) {
					/* In this scenario, we do the callback AND throw the active keys through.
					   This can be useful if you want to condense the inputs into one function rather than multiple.
					   This is not recommended, but do what you please. */
					if (i.debug != null) if (i.debug) trace("Key release input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(keysActive);
				}
			}
		}
	}

	// THIS DOES LITERALLY THE SAME THING WITH CONTROLS. THIS IS MAINLY THERE FOR FLXG.KEYS
	private function updateKeyDown() {
		// KEY DOWN
		if (keyDownCallbacks == null) return;
		for (i in keyDownCallbacks) {
			if (!i.useMultipleKeys || i.keys == null) {
				var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
				var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
				var controlActive:Bool = getInputDown(i.input, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
				if (controlActive) {
					if (i.debug != null) if (i.debug) trace("Key down input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(null); // Do the callback, but throw null because no data to be sent
				}
			} else {
				// The case in which i actually use the multiple keys BS (aka never)
				var keysActive:Map<String, Bool> = new Map<String, Bool>();
				var doCallback:Bool = false;

				for (j in i.keys) {
					var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
					var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
					var controlActive:Bool = getInputDown(j, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
					if (controlActive && !doCallback) doCallback = true;
					if (controlActive) keysActive.set(j, controlActive);
				}

				if (doCallback) {
					/* In this scenario, we do the callback AND throw the active keys through.
					   This can be useful if you want to condense the inputs into one function rather than multiple.
					   This is not recommended, but do what you please. */
					if (i.debug != null) if (i.debug) trace("Key down input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(keysActive);
				}
			}
		}
	}

	// THIS DOES LITERALLY THE SAME THING WITH CONTROLS. THIS IS MAINLY THERE FOR FLXG.KEYS
	// Another note: This will only activate if ALL keys in the callback are not down.
	private function updateKeyUp() {
		// KEY UP
		if (keyUpCallbacks == null) return;
		for (i in keyUpCallbacks) {
			if (!i.useMultipleKeys || i.keys == null) {
				var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
				var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
				var controlActive:Bool = getInputDown(i.input, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
				if (!controlActive) {
					if (i.debug != null) if (i.debug) trace("Key up input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(null); // Do the callback, but throw null because no data to be sent
				}
			} else {
				// The case in which i actually use the multiple keys BS (aka never)
				var keysActive:Map<String, Bool> = new Map<String, Bool>();
				var doCallback:Bool = true;

				for (j in i.keys) {
					var isSpecialKey:Bool = (i.isSpecialKey != null ? i.isSpecialKey : false);
					var specialInputData:SpecialInput = (i.specialInput != null? i.specialInput : null);
					var controlActive:Bool = getInputDown(j, isSpecialKey, (specialInputData != null ? specialInputData.type : null));
					if (controlActive && doCallback) doCallback = false;
					if (!controlActive) keysActive.set(j, controlActive);
				}

				if (doCallback) {
					/* In this scenario, we do the callback AND throw the active keys through.
					   This can be useful if you want to condense the inputs into one function rather than multiple.
					   This is not recommended, but do what you please. */
					if (i.debug != null) if (i.debug) trace("Key up input activated with the nametag '" + (i.name != null ? i.name : "[unnamed]") + "'.");
					i.callback(keysActive);
				}
			}
		}
	}

	inline function updateBeat():Void 
		curBeat = Math.floor(curStep / 4);

	private function updateCurStep():Void {
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}

		for (i in 0...Conductor.bpmChangeMap.length) {
			if (Conductor.songPosition >= Conductor.bpmChangeMap[i].songTime) {
				lastChange = Conductor.bpmChangeMap[i];
			}
		}

		curStep = lastChange.stepTime + Math.floor(((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / Conductor.stepCrochet);
	}

	public static function switchState(nextState:FlxState) {
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;

		if(!FlxTransitionableState.skipNextTransIn) {
			leState.openSubState(new CustomFadeTransition(0.7, false));
			if(nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = function() {
					FlxG.resetState();
				};
			} else {
				CustomFadeTransition.finishCallback = function() {
					FlxG.switchState(nextState);
				};
			}
			return;
		}

		FlxTransitionableState.skipNextTransIn = false;
		FlxG.switchState(nextState);
	}

	public static function resetState() {
		MusicBeatState.switchState(FlxG.state);
	}

	public static function getState():MusicBeatState {
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;
		return leState;
	}

	public function stepHit():Void {
		if (curStep % 4 == 0) beatHit();
	}

	public function beatHit():Void {}
}
