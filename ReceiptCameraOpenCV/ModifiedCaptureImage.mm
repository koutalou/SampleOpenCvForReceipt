//
//  ModifiedCaptureImage.m
//  ReceiptCameraOpenCV
//
//  Created by koutalou on 2017/06/29.
//  Copyright © 2017年 koutalou. All rights reserved.
//

#import "ModifiedCaptureImage.h"

@implementation ModifiedCaptureImage: NSObject

bool bigger( const std::vector < cv::Point >& left, const std::vector < cv::Point >& right ) {
    return contourArea(left,false) > contourArea(right,false);
};

+ (UIImage *)filterImage:(UIImage *)image {
    // 座標の軸が合ってないので調整
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //UIImageをcv::Matに変換
    cv::Mat originalMat;
    cv::Mat greyMat;
    cv::Mat homographyBaseMat;
    cv::Mat homographyMat;
    cv::Mat binarizationMat;
    cv::Mat resultMat;
    UIImageToMat(image, originalMat);
    
    //グレースケールに変更
    cv::cvtColor(originalMat,greyMat,CV_BGR2GRAY);

    // 処理1
    // - レシートの情報鮮明化
    
    cv::fastNlMeansDenoising(greyMat, binarizationMat);
    cv::adaptiveThreshold(binarizationMat, resultMat, 255, cv::ADAPTIVE_THRESH_MEAN_C, cv::THRESH_BINARY, 63, 5);
    
    // 処理2
    // - レシートの矩形調整処理
    
    // Blurをかける
    cv::blur(greyMat, homographyBaseMat, cv::Size(3,3));
    
    std::vector< std::vector < cv::Point > > vctContours;
    std::vector< cv::Vec4i > hierarchy;
    //cv::Scalar sclColor;
    
    // Cannyアルゴリズムを使ったエッジ検出
    Canny(homographyBaseMat, homographyMat, 100, 100, 3);
    // 輪郭を取得する
    cv::findContours(homographyMat, vctContours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
    
    // 大きい順にソート
    std::sort(vctContours.begin(), vctContours.end(), bigger);
    
    for( int i = 0; i < (int)vctContours.size(); i++) {
        if(contourArea(vctContours[i],false) < 15000) {
            // 小さな輪郭は除く
            continue;
        }
        
        std::vector<cv::Point> approx;
        cv::approxPolyDP(cv::Mat(vctContours[i]), approx, 0.01 * cv::arcLength(vctContours[i], true), true);
        if (approx.size() != 4) {
            // 四角形以外の矩形は除く
            continue;
        }
        
        cv::Point2f src[4] = {approx[0], approx[1], approx[2], approx[3]}; // 変換元
        
        float min_x = INT32_MAX;
        float max_x = 0;
        float min_y = INT32_MAX;
        float max_y = 0;
        int zero_position = 0;
        
        for (int i = 0; i < 4; i++) {
            if (approx[i].x > max_x) max_x = approx[i].x;
            if (approx[i].x < min_x) min_x = approx[i].x;
            if (approx[i].y > max_y) max_y = approx[i].y;
            if (approx[i].y < min_y) min_y = approx[i].y;
        }
        
        for (int i = 1; i < 4; i++) {
            if (((approx[i].x - min_x) * (approx[i].x - min_x) + (approx[i].y - min_y) * (approx[i].y - min_y)) < ((approx[zero_position].x - min_x) * (approx[zero_position].x - min_x) + (approx[zero_position].y - min_y) * (approx[zero_position].y - min_y)) ) {
                zero_position = i;
            }
        }
        
        // レシートのアスペクト比を維持したサイズ計算
        int height = homographyBaseMat.size().height;
        int width = int(homographyBaseMat.size().width * (max_x - min_x) / (max_y - min_y));
        
        // 変換後の座標は縦幅いっぱいの長方形レシート
        cv::Point2f dstBase[4] = {cv::Point2f(0, 0), cv::Point2f(0, height), cv::Point2f(width, height), cv::Point2f(width, 0)};
        // 変換後の座標を元々の座標の近傍の順番に調整
        cv::Point2f dst[4] = {dstBase[(4 - zero_position) % 4], dstBase[(4 - zero_position + 1) % 4], dstBase[(4 - zero_position + 2) % 4], dstBase[(4 - zero_position + 3) % 4]};
        
        // 台形補正(透視変換)
        cv::Mat perspective_matrix = cv::getPerspectiveTransform(src, dst);
        cv::warpPerspective(resultMat, resultMat, perspective_matrix, homographyBaseMat.size(), cv::INTER_NEAREST);
        
        // 処理を行うのは一番大きな矩形のみ
        break;
    }
    
    return MatToUIImage(resultMat);
}

+ (UIImage *)testFilterImage:(UIImage *)image type:(ImageConvertType)type {
    // 座標の軸が合ってないので調整
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //UIImageをcv::Matに変換
    cv::Mat originalMat;
    cv::Mat mat;
    UIImageToMat(image, originalMat);
    UIImageToMat(image, mat);
    if (type & grey) {
        //グレースケールに変更
        cv::cvtColor(originalMat,mat,CV_BGR2GRAY);
        cv::cvtColor(originalMat,originalMat,CV_BGR2GRAY);
    }
    
    // Blur
    cv::blur(mat, mat, cv::Size(3,3));
    cv::threshold(originalMat, originalMat, 100, 0, CV_THRESH_TOZERO );
    
    cv::Mat matCanny;
    cv::Mat matCanny2;
    cv::Mat ouput;
    std::vector< std::vector < cv::Point > > vctContours;
    std::vector< cv::Vec4i > hierarchy;
    cv::Scalar sclColor;
    // 乱数生成器
    cv::RNG rngColor;
    
    // Cannyアルゴリズムを使ったエッジ検出
    Canny(mat, matCanny, 100, 100, 3);
    // 輪郭を取得する
    cv::findContours(matCanny, vctContours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);

    //////////////////////////////////
    // ノイズ除去&カスタム2値化(5pixel以上ないと)
    //////////////////////////////////
    
    cv::Mat edgeMat;
    cv::fastNlMeansDenoising(originalMat, originalMat);
    cv::adaptiveThreshold(originalMat, ouput, 255, cv::ADAPTIVE_THRESH_MEAN_C, cv::THRESH_BINARY, 63, 5); // ADAPTIVE_THRESH_MEAN_C;
    return MatToUIImage(ouput);
    
    //////////////////////////////////
    // Edge検出による2値化(ダメそう)
    //////////////////////////////////
    
    // Cannyアルゴリズムを使ったエッジ検出
    Canny(originalMat, edgeMat, 50, 100, 3);
    // 輪郭を取得する
    cv::findContours(edgeMat, vctContours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_TC89_L1);
    
    std::sort(vctContours.begin(), vctContours.end(), bigger);
    
    // 輪郭を表示する
    //cv::Mat edgeMat = cv::Mat::zeros(matCanny.size(), CV_8UC3 );
    
    for( int i = 1; i < (int)vctContours.size(); i++) {
        sclColor = cv::Scalar(255, 255,255);//rngColor.uniform(0, 255), rngColor.uniform(0,255), rngColor.uniform(0,255) );
        cv::drawContours(edgeMat, vctContours, i, sclColor, 0); //CV_FILLED);
    }
    cv::bitwise_not(edgeMat, edgeMat); // 白黒の反転
    return MatToUIImage(edgeMat);
    
    /////////////////////////////////////////////////////////////////////////////////
    // v2 - 大きな矩形(レシート)に合わせて台形補正(透視変換/Homography Transformation)切り出し
    /////////////////////////////////////////////////////////////////////////////////
    
    for( int i = 0; i < (int)vctContours.size(); i++) {
    //for( int i = (int)vctContours.size(); 0 <= i; i--)
    //{
        if(contourArea(vctContours[i],false) < 15000) {
            // 小さな輪郭は除く
            continue;
        }
        
        std::vector<cv::Point> approx;
        cv::approxPolyDP(cv::Mat(vctContours[i]), approx, 0.01 * cv::arcLength(vctContours[i], true), true);
        if (approx.size() != 4) {
            // 四角形以外の矩形は除く
            continue;
        }
        
        // 認識できた四角形の輪郭にランダムで色を付ける
        sclColor = cv::Scalar(255, 0,0);//rngColor.uniform(0, 255), rngColor.uniform(0,255), rngColor.uniform(0,255) );
        cv::drawContours(mat, vctContours, i, sclColor, 5);

        cv::Point2f src[4]; // 変換元
        //cv::Point2f dst[4]; // 変換先
        src[0] = approx[0];
        src[1] = approx[1];
        src[2] = approx[2];
        src[3] = approx[3];
        
        float min_x = INT32_MAX;
        float max_x = 0;
        float min_y = INT32_MAX;
        float max_y = 0;
        int zero_position = 0;
        
        for (int i = 0; i < 4; i++) {
            if (approx[i].x > max_x) max_x = approx[i].x;
            if (approx[i].x < min_x) min_x = approx[i].x;
            if (approx[i].y > max_y) max_y = approx[i].y;
            if (approx[i].y < min_y) min_y = approx[i].y;
        }
        
        for (int i = 1; i < 4; i++) {
            if (((approx[i].x - min_x) * (approx[i].x - min_x) + (approx[i].y - min_y) * (approx[i].y - min_y)) < ((approx[zero_position].x - min_x) * (approx[zero_position].x - min_x) + (approx[zero_position].y - min_y) * (approx[zero_position].y - min_y)) ) {
                zero_position = i;
            }
        }
        
        int height = matCanny.size().height;
        int width = int(matCanny.size().width * (max_x - min_x) / (max_y - min_y));
        
        cv::Point2f dstBase[4] = {cv::Point2f(0, 0), cv::Point2f(0, height), cv::Point2f(width, height), cv::Point2f(width, 0)};
        cv::Point2f dst[4] = {dstBase[(4 - zero_position) % 4], dstBase[(4 - zero_position + 1) % 4], dstBase[(4 - zero_position + 2) % 4], dstBase[(4 - zero_position + 3) % 4]};
        //cv::Point2f dst[4] = {cv::Point2f(min_x, min_y), cv::Point2f(min_x, max_y), cv::Point2f(max_x, max_y), cv::Point2f(max_x, min_y)};
        
        cv::Mat perspective_matrix = cv::getPerspectiveTransform(src, dst);
        cv::warpPerspective(originalMat, originalMat, perspective_matrix, mat.size(), cv::INTER_NEAREST);
        break;
    }
    
    return MatToUIImage(originalMat);

    /////////////////////////////////
    // v1 - 大きな矩形(レシート)切り出し
    /////////////////////////////////

    /*
    cv::threshold(mat, mat, 200, 255, CV_THRESH_TOZERO_INV );
    cv::bitwise_not(mat, mat); // 白黒の反転
    cv::threshold(mat, mat, 0, 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
    cv::findContours(mat, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_TC89_L1);

    int max_level = 0;
    for(int i = 0; i < contours.size(); i++){
        cv::drawContours(mat, contours, i, cv::Scalar(255, 0, 0, 255), 3, CV_AA, hierarchy, max_level);
    }
    
    int max_level = 0;
    for(int i = 0; i < contours.size(); i++) {
        // ある程度の面積が有るものだけに絞る
        double a = contourArea(contours[i],false);
        if(a > 15000) {
            //輪郭を直線近似する
            std::vector<cv::Point> approx;
            cv::approxPolyDP(cv::Mat(contours[i]), approx, 0.01 * cv::arcLength(contours[i], true), true);
            // 矩形のみ取得
            if (approx.size() == 4) {
                cv::drawContours(mat, contours, i, cv::Scalar(255, 0, 0, 255), 3, CV_AA, hierarchy, max_level);
            }
        }
    }*/
    
    return MatToUIImage(mat);
}

@end
