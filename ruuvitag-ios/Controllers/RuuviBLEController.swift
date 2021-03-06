//
//  BLEController.swift
//  ruuvitag-ios
//
//  Created by Tomi Lahtinen on 12/06/2018.
//  Copyright © 2018 Tomi Lahtinen. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol RuuviTags {
    func startScanning()
    func stopScanning()
}

extension RuuviTags {
    public static func listen(forAdvertisement dataReceived: @escaping (TagInfo) -> ()) -> RuuviTags {
        return RuuviTagConnector(dataReceived)
    }
}

fileprivate class RuuviTagConnector: NSObject, RuuviTags {

    private let advertisementData: (TagInfo) -> ()
    private var centralManager: CBCentralManager
    private let dataDispatchQueue = DispatchQueue(label: "RuuviData_DispatchQueue")
    
    fileprivate init(_ advertisementData: @escaping (TagInfo) -> ()) {
        self.advertisementData = advertisementData
        
        let opts = [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: true,
                    CBCentralManagerOptionShowPowerAlertKey: true,
                    CBCentralManagerScanOptionAllowDuplicatesKey: true]
        self.centralManager = CBCentralManager(delegate: nil, queue: self.dataDispatchQueue, options: opts)
        
        super.init()
        centralManager.delegate = self
    }
    
    fileprivate func startScanning() {
        if !centralManager.isScanning {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    fileprivate func stopScanning() {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
    }
}

extension RuuviTagConnector: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch centralManager.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        default:
            debugPrint("Central manager state", centralManager.state)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey],
            let rawData = DataFormat3.decode(data: manufacturerData as? Data, rssi: RSSI.intValue) {
            let sensorValues = SensorValues.init(data: rawData)
            self.advertisementData(TagInfo(uuid: peripheral.identifier, name: peripheral.name, sensorValues: sensorValues))
        }
    }
}
