// Rebuild only the q descender and remove the old i dot. No font rendering or canvas resampling.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let directory=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
func read(_ url:URL)->CGImage {CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL,nil)!,0,nil)!}
let original=read(directory.appendingPathComponent("start_title_logo_original.png"))
let mask=read(directory.appendingPathComponent("q_tail_mask.png"))
precondition(original.bitsPerPixel==32 && original.alphaInfo == .last)
precondition(mask.bitsPerPixel==32 && mask.alphaInfo == .last)
var data=[UInt8](original.dataProvider!.data! as Data)
let before=data
let maskData=[UInt8](mask.dataProvider!.data! as Data)
let tailRegion=CGRect(x:440,y:1667,width:74,height:56)
let dotRegion=CGRect(x:795,y:1508,width:78,height:50)
for rect in [tailRegion,dotRegion] {
 for y in Int(rect.minY)..<Int(rect.maxY) {for x in Int(rect.minX)..<Int(rect.maxX) {
  let i=y*original.bytesPerRow+x*4
  for c in 0..<4 {data[i+c]=0}
 }}
}
// Reference A's 24px stem joins the original 27px stem without touching the q bowl.
let scale=1.125, x0=473.5-(326.5-300)*1.125, y0=1667.0
func alpha(_ x:Int,_ y:Int)->Double {
 guard x>=0,y>=0,x<mask.width,y<mask.height else{return 0}
 return Double(maskData[y*mask.bytesPerRow+x*4+3])
}
for y in Int(tailRegion.minY)..<Int(tailRegion.maxY) {for x in Int(tailRegion.minX)..<Int(tailRegion.maxX) {
 let sx=(Double(x)+0.5-x0)/scale-0.5,sy=(Double(y)+0.5-y0)/scale-0.5
 let ix=Int(floor(sx)),iy=Int(floor(sy)),fx=sx-floor(sx),fy=sy-floor(sy)
 let a=(alpha(ix,iy)*(1-fx)+alpha(ix+1,iy)*fx)*(1-fy)+(alpha(ix,iy+1)*(1-fx)+alpha(ix+1,iy+1)*fx)*fy
 let opacity=UInt8(max(0,min(255,a.rounded())))
 if opacity>0 {let i=y*original.bytesPerRow+x*4;data[i]=255;data[i+1]=255;data[i+2]=255;data[i+3]=opacity}
}}
let result=CGImage(width:original.width,height:original.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:original.bytesPerRow,space:original.colorSpace!,bitmapInfo:original.bitmapInfo,provider:CGDataProvider(data:Data(data) as CFData)!,decode:nil,shouldInterpolate:original.shouldInterpolate,intent:original.renderingIntent)!
let output=directory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("PomodoroAquarium/Assets.xcassets/start_title_logo.imageset/start_title_logo.png")
let destination=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,result,nil);precondition(CGImageDestinationFinalize(destination))
// Verify decoded RGBA bytes: every pixel outside the two edit regions is identical.
let saved=read(output)
let savedBytes=[UInt8](saved.dataProvider!.data! as Data)
precondition(saved.bytesPerRow==original.bytesPerRow)
var changed=0
for y in 0..<original.height {for x in 0..<original.width {
 let i=y*original.bytesPerRow+x*4
 if before[i..<i+4] != savedBytes[i..<i+4] {
  precondition(tailRegion.contains(CGPoint(x:x,y:y)) || dotRegion.contains(CGPoint(x:x,y:y)))
  changed += 1
 }
}}
print("Logo saved; \(changed) changed pixels confined to q tail and old i dot. Other pixels unchanged.")
