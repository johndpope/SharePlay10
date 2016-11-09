
//
//  NetworkCommunicater.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/11/09.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
import MultipeerConnectivity
class NetworkCommunicater: NSObject,MCSessionDelegate{
    private let bufferSize = 32768
    
    var session:MCSession!
    
    dynamic var peerNameArray:[String] = []
    
    var isParent:Bool = false
    
    private var sendQueue:[NSData] = []
    
    dynamic var artImage:UIImage!
    
    private var musicName:String?
    
    private var tempData:NSMutableData!//ファイルの容量が大きいものを受信する時用
    
    private var timer:Timer!
    
    private var delayTime:Double!
    enum dataType:Int {//送信するデータのタイプ
        case isString = 1
        case isImage = 2
        case isAudio = 3
    }
    dynamic var recvStr:String? = nil
    dynamic var audioData:NSData!
   func  prepare() {
    
        isParent = false
        delayTime = 0.6
        tempData = NSMutableData()

    }
    func createSessionwithID(peerID:MCPeerID){
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)//↑で作ったIDを利用してセッションを作成
        session.delegate = self
    }
    func sendDataInterval(){
        if sendQueue.count > 0{
            do {
                try session.send(sendQueue[0] as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                sendQueue.remove(at: 0)
                
            }catch{
                
                print("Send Failed")
            }
            
        }
        
    }
    func sendStr(str:String) -> Void {
        let orderData = str.data(using: String.Encoding.utf8)
        sendData(data: orderData! as NSData, option: dataType.isString)
    }
    func sendAudiodata(data:NSData){
        sendData(data: data, option: dataType.isAudio)
        if self.timer != nil {
            timer.invalidate()
        }
        timer = Timer.scheduledTimer(timeInterval:delayTime, target: self, selector: #selector(NetworkCommunicater.sendDataInterval), userInfo: nil, repeats: true)
        timer.fire()
    }
    func sendImage(image:UIImage){
        let imageData:NSData = UIImagePNGRepresentation(image)! as NSData
        sendData(data: imageData, option: dataType.isImage)
    }
    func sendData(data:NSData,option:dataType) -> () {
        
        var splitDataSize = bufferSize
        //var indexofData = 0
        var buf = Array<Int8>(repeating: 0, count: bufferSize)
        //var error: NSError!
        var tempData = NSMutableData()
        var index = 0
        let sendDataArray = NSMutableArray()
        sendDataArray[0] = option.rawValue
        sendDataArray[1] = 1
        while index < data.length {
            
            if (index >= data.length-bufferSize) || (data.length < bufferSize) {
                splitDataSize = data.length - index
                buf = Array<Int8>(repeating: 0, count: splitDataSize)
                
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf, length: splitDataSize)
                sendDataArray[2] = tempData
                sendDataArray[1] = 0//ファイルの終了をお知らせ
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                if option == dataType.isAudio{
                    sendQueue.append(sendingData as NSData)
                }else{
                    do {
                        try session.send(sendingData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                        
                    }catch{
                        
                        print("Send Failed")
                    }
                }
            }else{
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf,length:splitDataSize)
                sendDataArray[2] = tempData
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                if option == dataType.isAudio{
                    sendQueue.append(sendingData as NSData)
                }else{
                    do {
                        try session.send(sendingData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                        
                    }catch{
                        
                        print("Send Failed")
                    }
                }
            }
            index=index+bufferSize
        }
        
    }

    // MARK: MCSessionDelegate
     public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID){
        let recvDataArray:NSMutableArray! = NSKeyedUnarchiver.unarchiveObject(with: data) as! NSMutableArray!
        if recvDataArray != nil{
            let  recvType:Int = recvDataArray[0] as! Int
            let recvContents:Data =  recvDataArray[2] as! Data
            
            if recvType  == dataType.isAudio.rawValue{//中身がオーディオデータのとき
                
                   audioData = recvContents as NSData!
                    
                
            }else if recvType == dataType.isString.rawValue{//中身が文字列のとき
                let str = NSString(data: recvContents, encoding: String.Encoding.utf8.rawValue) as String?
                recvStr = str

            }else if recvType == dataType.isImage.rawValue{//中身が画像のとき
                let isFin = recvDataArray[1] as! Int
                if isFin == 0 {
                    tempData.append(recvContents)
                    print("画像のデータサイズ",tempData.length)
                        self.artImage = UIImage(data: tempData as Data)
                        //画像の変更を反映する処理
                        self.tempData = NSMutableData()
                        //ここでNSDataからUIimageに変換を入れて　artImageに設定
                }else{
                    tempData.append(recvContents)
                    
                }
                
            }
            
        }
        recvDataArray.removeAllObjects()

    }
     public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState){
        if state == MCSessionState.connected{
            print(peerID.displayName)
            peerNameArray.append(peerID.displayName)
            
            print("接続完了")
           
        }
        if state == MCSessionState.notConnected{
            var num = 0
            for name in peerNameArray {
                
                if name == peerID.displayName{
                    print(peerNameArray[num])
                    peerNameArray.remove(at: num)
                    num = num + 1
                }
            }
            if peerNameArray.count == 0{
                print("誰も居ないのでもどる")
                
            }
            
            print("接続解除")
        }

    }
    // MARK: 使わんやつ
    // ピアからストリームを受信したとき.
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID){
    }
    // リソースからとってくるとき（URL指定とか？).
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress){
    }
    // そのとってくるやつが↑終わったとき
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?){
    }
}
