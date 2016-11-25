/*----------------------------------------------------------------------------
    Concrète Mixer - an ambient sound jukebox for the Raspberry Pi

    Copyright (c) 2014-2016 Stuart McDonald  All rights reserved.
        https://github.com/concrete-mixer/concrete-mixer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
    U.S.A.
-----------------------------------------------------------------------------*/


class Dispatch {
    0 => int fxMachineId;
    0 => int ending;

    int streamsActive[0];
    Fader f;

    26 => int fxChainsCount;

    if ( Config.rpi ) {
        20 => fxChainsCount;
    }

    int fxChainsUsed[0];

    Chooser c;

    fun void initialise() {
        0 => int altSent;

        for ( 0 => int i; i < Config.streamData.streamsAvailable.size(); i++ ) {
            Config.streamData.streamsAvailable[i] => string stream;

            // set concurrent sounds for each stream to 1 by default
            1 => int concurrentSounds;

            if ( Config.streamData.concurrentSounds[stream] ) {
                Config.streamData.concurrentSounds[stream] => concurrentSounds;
            }

            for ( 0 => int j; j < concurrentSounds; j++ ) {
                if ( Config.streamData.files[stream].size() ) {
                    playSound(stream);
                    1 => streamsActive[stream];
                }
                else {
                    <<< "No files available for stream", stream, "exiting" >>>;
                    me.exit();
                }
            }
        }

        if ( Config.fxChainEnabled ) {
            getFxChain() => int fxChain;

            // keep track of the machine id for fx chain so we can scupper it
            // when file playback is complete.
            Machine.add(me.dir() + "playFxChain.ck:" + fxChain) => fxMachineId;
        }

        OscIn oin;
        3141 => oin.port;

        "/playsound" => oin.addAddress;
        "/playfxchain" => oin.addAddress;

        OscMsg msg;

        // start listening for packets notifying server that playback
        // for each playFx and playSound has finished
        while ( true ) {
            oin => now;

            while(oin.recv(msg)) {
                // stream is always the first arg if there are args
                msg.getString(0) => string stream;

                chout <= "Received " <= msg.address <= IO.nl();

                if ( msg.address == "/playsound" ) {
                    playSound(stream);
                }

                if ( msg.address == "/playfxchain" ) {
                    getFxChain() => int fxChain;

                    // keep track of the machine id for fx chain so we can scupper it
                    // when file playback is complete.

                    Machine.add(me.dir() + "playFxChain.ck:" + fxChain) => fxMachineId;
                }
            }
        }
    }

    fun string getFileToPlay(string stream) {
        // set up our vars
        string target[];
        string file;

        Config.streamData.files[stream] @=> target;

        // if target array empty return empty string
        // means playSound.ck won't be invoked
        if ( ! target.size() ) {
            return "";
        }

        Math.random2(0, target.size() - 1) => int key;

        target[key] => file;

        removeFile(key, stream);

        return Config.streamData.filePaths[stream] + "/" + file;
    }

    fun void removeFile(int key, string stream) {
        // because ChucK is fucking primitive, we can't remove items from
        // an array - we have to reconstruct it
        string target[];
        string file, filePath;

        Config.streamData.files[stream] @=> target;

        target.size() => int size;
        string newArray[0];

        for ( int i; i < size; i++ ) {
            if ( i != key ) {
                newArray << target[i];
            }
        }

        newArray @=> Config.streamData.files[stream];
    }

    fun void playSound( string stream ) {
        getFileToPlay(stream) => string filePath;

        if ( filePath != "" ) {
            me.dir() + "playSound.ck:" + filePath + ":" + stream => string args;

            Machine.add(args);
        }
        else {
            0 => streamsActive[stream];

            if ( lastStream() ) {
                endActivity();
            }
        }
    }

    fun int lastStream() {
        1 => int streamIsLast;

        // Determine if any streams are still active
        for ( int i; i < streamsActive.size(); i++ ) {
            if ( streamsActive[i] ) {
                // there is another stream still active
                // so return false
                0 => streamIsLast;
            }
        }

        return streamIsLast;
    }

    fun void endActivity() {
        2 * Time.barDur => dur fadeDur;

        // 2. Start fade
        f.fadeOut(fadeDur, Mixer.leftOut);
        f.fadeOut(fadeDur, Mixer.rightOut);

        // If a playFxChain still running, remove it
        Machine.remove(fxMachineId);

        1 => Config.ended;

        <<< "Dispatcher signing out" >>>;

        me.exit();
    }

    fun int getFxChain() {
        if ( fxChainsUsed.size() == fxChainsCount ) {
            int fxChainsUsed[0];
        }

        c.getInt(1, fxChainsCount) => int choice;

        for (int i; i < fxChainsUsed.size(); i++ ) {
            if ( fxChainsUsed[i] == choice ) {
                // find another choice
                return getFxChain();
            }
        }

        fxChainsUsed << choice;

        return choice;
    }
}

Dispatch dispatch;

dispatch.initialise();
