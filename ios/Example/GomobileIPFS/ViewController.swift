//
//  ViewController.swift
//  GomobileIPFS
//
//  Created by gfanton on 10/30/2019.
//  Copyright (c) 2019 gfanton. All rights reserved.
//

import UIKit
import GomobileIPFS

class ViewController: UIViewController {
    @IBOutlet var PIDTitle: UILabel!
    @IBOutlet var PIDInfo: UILabel!
    @IBOutlet var PIDLoading: UIActivityIndicatorView!
    @IBOutlet weak var PeerCounter: UILabel!
    @IBOutlet weak var XKCDButton: UIButton!
    @IBOutlet weak var FetchProgress: UIActivityIndicatorView!
    @IBOutlet weak var FetchStatus: UILabel!
    @IBOutlet weak var FetchError: UILabel!

    static var ipfs: IPFS?

    var peerID : String?
    var peerCountUpdater: PeerCountUpdater?
    var xkcdList: NSArray?

    static func getIpfs() -> IPFS? {
        return ipfs
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.PIDLoading.startAnimating()

        XKCDButton.addTarget(
          self,
          action: #selector(xkcdButtonClicked),
          for: .touchUpInside
        )

        DispatchQueue.global(qos: .background).async {
            var error: String?

            do {
                ViewController.ipfs = try IPFS()
                try ViewController.ipfs!.start()

                let res = try ViewController.ipfs!.commandToDict("id")
                self.peerID = (res["ID"] as! String)
            } catch let err as IPFSError {
                error = err.localizedFullDescription
            } catch let err {
                error = err.localizedDescription
            }

            if let err = error {
                DispatchQueue.main.async { self.displayPeerIDError(err) }
            } else {
                DispatchQueue.main.async { self.displayPeerID() }

                do {
                    let xkcdJson = Bundle.main.path(forResource: "xkcd", ofType: "json", inDirectory: "Data")
                    let raw = try Data(contentsOf: URL(fileURLWithPath: xkcdJson!), options: .mappedIfSafe)
                    let parsedJson = try JSONSerialization.jsonObject(with: raw, options: .mutableLeaves) as! [String: Any]
                    let xkcdList = parsedJson["xkcd-list"] as! NSArray
                    self.xkcdList = xkcdList
                    DispatchQueue.main.async { self.XKCDButton.isEnabled = true }
                } catch let error {
                    print("Error: can't parse xkcd-list json: \(error)")
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        self.peerCountUpdater?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.peerCountUpdater?.stop()
    }

    private func displayPeerID() {
        self.PIDLoading.stopAnimating()
        self.PIDTitle.text = "Your PeerID is:"
        self.PIDInfo.text = self.peerID!

        print("Your PeerID is: \(self.peerID!)")
        initPeerCountUpdater()

        XKCDButton.isHidden = false
    }

    private func displayPeerIDError(_ error: String) {
        self.PIDLoading.stopAnimating()

        PIDTitle.textColor = UIColor.red
        PIDInfo.textColor = UIColor.red

        self.PIDTitle.text = "Error:"
        self.PIDInfo.text = error

        print("IPFS start error: \(error)")
    }

    private func displayFetchProgress() {
        FetchStatus.textColor = UIColor.black
        FetchStatus.text = "Fetching XKCD on IPFS"
        FetchStatus.isHidden = false
        FetchProgress.startAnimating()
        FetchError.isHidden = true
        XKCDButton.isEnabled = false
    }

    private func displayFetchSuccess(_ title: String, _ image: UIImage) {
        FetchStatus.isHidden = true
        FetchProgress.stopAnimating()
        XKCDButton.isEnabled = true

        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let displayImageController = storyBoard.instantiateViewController(withIdentifier: "DisplayImage") as! DisplayImageController
        displayImageController.xkcdTitle = title
        displayImageController.xkcdImage = image
        self.navigationController!.pushViewController(displayImageController, animated: true)
    }

    private func displayFetchError(_ error: String) {
        FetchStatus.textColor = UIColor.red
        FetchStatus.text = "Fetching XKCD failed"
        FetchProgress.stopAnimating()
        FetchError.isHidden = false
        FetchError.text = error
        XKCDButton.isEnabled = true
    }

    private func initPeerCountUpdater() {
        self.peerCountUpdater = PeerCountUpdater()
        self.peerCountUpdater!.start()

        PeerCounter.text = "Peers connected: 0"
        PeerCounter.isHidden = false

        NotificationCenter.default.addObserver(
          self,
          selector: #selector(updatePeerCount(_:)),
          name: Notification.Name("updatePeerCount"),
          object: nil
        )
    }

    @objc func updatePeerCount(_ notification: Notification) {
        var count: Int = 0

        if let data = notification.userInfo as? [String: Int] {
            count = data["peerCount"] ?? 0
        }

        PeerCounter.text = "Peers connected: \(count)"
    }

    @objc func xkcdButtonClicked() {
        self.displayFetchProgress()

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now(), execute: {
            var error: String?
            var title: String = ""
            var image: UIImage = UIImage()

            do {
                let randomIndex = Int(arc4random_uniform(UInt32(self.xkcdList!.count)))
                let randomEntry = self.xkcdList![randomIndex] as! [String: Any]
                let cid = randomEntry["cid"] as! String
                let fetchedData = try ViewController.ipfs!.command("/cat?arg=\(cid)");

                title = "\(randomEntry["ep"] as! Int). \(randomEntry["name"] as! String)"
                image = UIImage(data: fetchedData)!
            } catch let err as IPFSError {
                error = err.localizedFullDescription
            } catch let err {
                error = err.localizedDescription
            }
            DispatchQueue.main.async {
                if let err = error {
                    self.displayFetchError(err)
                } else {
                    self.displayFetchSuccess(title, image)
                }
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .portrait
        }
    }
}
