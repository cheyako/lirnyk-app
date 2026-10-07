import Testing
@testable import Lirnyk

struct LaunchAtLoginTests {
    @Test(arguments: [
        (true, false, "/Applications/Lirnyk.app", true),
        (true, true, "/Applications/Lirnyk.app", false),
        (false, false, "/Applications/Lirnyk.app", false),
        (true, false, "/Volumes/Lirnyk/Lirnyk.app", false),
        (true, false, "/private/var/folders/xy/T/AppTranslocation/ABC/d/Lirnyk.app", false),
        (true, false, "/Users/me/lirnyk/build/DerivedData/Build/Products/Debug/Lirnyk.app", false),
    ])
    func shouldRegister(wanted: Bool, isEnabled: Bool, bundlePath: String, expected: Bool) {
        #expect(LaunchAtLogin.shouldRegister(wanted: wanted, isEnabled: isEnabled, bundlePath: bundlePath) == expected)
    }
}
