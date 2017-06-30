//
//  ReceiptCameraViewController.swift
//  ReceiptCameraOpenCV
//
//  Created by koutalou on 2017/06/29.
//  Copyright © 2017年 koutalou. All rights reserved.
//

import UIKit
import AVFoundation

class ReceiptCameraViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!
    
    var captureSession: AVCaptureSession = AVCaptureSession()
    var captureOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        setupCamera()
        startCamera()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: Event
extension ReceiptCameraViewController {
    @IBAction func tapCamera(_ sender: UIButton) {
        captureCamera()
    }
}

// MARK: Private
extension ReceiptCameraViewController {
    fileprivate func setupCamera() {
        let videoDevice: AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)

        // デバイスの接続
        let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice)
        captureSession.addInput(videoInput)
        
        // 出力の接続
        captureSession.addOutput(captureOutput)

        // 品質の設定
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            captureSession.sessionPreset = AVCaptureSessionPresetHigh
        }
        captureSession.commitConfiguration()
        
        // 撮影画像のViewへの割り当て
        if let videoLayer = AVCaptureVideoPreviewLayer.init(session: captureSession) {
            videoLayer.frame = cameraView.bounds
            videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            cameraView.layer.addSublayer(videoLayer)
        }
    }
    
    fileprivate func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    fileprivate func captureCamera() {
        captureOutput.captureStillImageAsynchronously(from: captureOutput.connection(withMediaType: AVMediaTypeVideo)) { (buffer, error) in
            
            guard let buffer = buffer, error == nil else {
                return
            }
            guard let image = self.convertJpgImage(buffer) else {
                return
            }
            
            guard let optimizeImage = ModifiedCaptureImage.filterImage(image) else {
                return
            }
            
            self.saveImage(image)
            self.saveImage(optimizeImage)
        }
    }
    
    fileprivate func convertJpgImage(_ buffer: CMSampleBuffer) -> UIImage? {
        guard let jpeg = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil) else {
            return nil
        }
        return UIImage(data:jpeg)
    }
    
    fileprivate func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, nil, nil)
    }
}

//
//// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
//extension ReceiptCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
//        
////        // UIImageへの変換
////        let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
////        // OpenCVでフィルタしてプレビューに表示
////        imageView.image = openCv.filter(image)
//    }
//}
