package org.rangerrobotics.pathplanner.io;

import java.awt.*;
import java.awt.event.KeyEvent;

public class KeyboardInput {
    private static volatile boolean isShiftPressed = false;

    public static boolean isShiftPressed(){
        return isShiftPressed;
    }

    public static void init(){
        KeyboardFocusManager.getCurrentKeyboardFocusManager().addKeyEventDispatcher(new KeyEventDispatcher() {
            @Override
            public boolean dispatchKeyEvent(KeyEvent e) {
                synchronized (KeyboardInput.class){
                    switch (e.getID()){
                        case KeyEvent.KEY_PRESSED:
                            if(e.getKeyCode() == KeyEvent.VK_SHIFT){
                                isShiftPressed = true;
                            }
                            break;
                        case KeyEvent.KEY_RELEASED:
                            if(e.getKeyCode() == KeyEvent.VK_SHIFT){
                                isShiftPressed = false;
                            }
                            break;
                    }
                    return false;
                }
            }
        });
    }
}
