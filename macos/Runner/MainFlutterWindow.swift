import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1280, height: 720)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()
    self.titleVisibility = NSWindow.TitleVisibility.hidden

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
