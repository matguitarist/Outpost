import Foundation
import Testing
@testable import OutpostKit

@Suite struct SSHClientTests {
    @Test func buildsArgumentsWithIdentityFile() {
        let client = SSHClient(target: "root@192.168.40.210", identityFile: "~/.ssh/id_ed25519_homeserver", port: 22)
        let args = client.sshArguments("uname -a")
        #expect(args.contains("-i"))
        #expect(args.contains("IdentitiesOnly=yes"))
        #expect(args.contains("root@192.168.40.210"))
        #expect(args.contains("uname -a"))
    }

    @Test func buildsArgumentsWithoutIdentityFile() {
        let client = SSHClient(target: "root@192.168.40.210")
        let args = client.sshArguments()
        #expect(!args.contains("-i"))
        #expect(args.contains("root@192.168.40.210"))
    }
}
