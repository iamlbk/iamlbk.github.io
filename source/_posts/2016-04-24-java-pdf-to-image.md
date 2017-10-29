---
layout: post
title: "pdf转图片(java语言实现)"
date: 2016-04-24 20:04:24 +0800
comments: true
categories: 编程语言
tags: [java, pdf2image, pdfbox]
keywords: pdf转image, pdfbox
---

由于项目需要将pdf转成图片, 所以学习了使用java将pdf文件转成图片的方法. 这里记录下方法, 方便以后查阅.

目前pdf转图片比较常用的类库有如下几个:

- [PDFRenderer][]: 开源, 是Swinglabs的一个子项目. 效率较高, 但是无法处理中文.
- [pdfbox][]: apache的一个开源项目, 部分支持中文, 有些中文pdf可以正常转换, 有些则完全无法转换, 比较消耗内存.
- [jpedal][]: 据说有开源和商业版本, 但是我只找到了商业版本, 而且价格不菲, 所以并没有试过...
- [ICEPDF][]: 有开源和商业版本. 开源的也是部分支持中文, 商业版的并没有尝试过.

上面所说的四种工具, 只有pdfbox能支持项目中用到的中文pdf. 所以我使用的是pdfbox. 但是在解决过问题以后, 我使用其他的pdf文件测试时, 有些中文pdf文件转换过之后就只剩下乱码了. 如果需要完美的中文支持, 可能只有使用 jpedal 或者 ICEPDF 的商业版才行吧?

<!--more-->
## 下载
目前(2016/04/24)pdfbox的最新版本为2.0.0. 我使用的版本为1.8.11. maven坐标如下:

``` xml
<dependency>
    <groupId>org.apache.pdfbox</groupId>
    <artifactId>pdfbox</artifactId>
    <version>1.8.11</version>
</dependency>
```

也可以直接从pdfbox的下载页面下载: http://pdfbox.apache.org/download.cgi

## 将pdf文件转成图片文件
如果只是需要将pdf文件转成图片文件还是比较简单的, 只需要简单的6,7行代码就行了:

``` java PDF2Image
private static final String BASE_PATH = "F:\\java\\";

public static void main(String[] args) throws IOException {
    File file = new File(BASE_PATH + "test.pdf");
    PDDocument doc = PDDocument.load(file);
    PDFImageWriter imageWriter = new PDFImageWriter();

    int pageCount = doc.getNumberOfPages();
    for (int i = 1; i <= pageCount; i++) {
        // 将第 i 到 i 页(也就是第i页)转换成图片, 并存到文件中
        imageWriter.writeImage(doc, "jpg", null, i, i, BASE_PATH + file.getName());
    }
}
```

过程很简单, 加载pdf文件. 创建一个输出流. 遍历pdf文件的每一页, 输出到图片文件中即可.

其中`PDDocument.load`有多个重载方法, 最简单的四个重载方法分别接受`String`类型的参数, `File`类型的参数; `URL`类型的参数, 或者`InputStream`类型的参数.

而在输出时的`imageWrite.writeImage`方法的第二个参数指定图片类型, 这个参数也决定了生成图片文件的缩略名.

## 将pdf转换成图片, 并输出到内存的缓存中
我们可能需要将pdf转换成图片, 并存到内存中进行下一步处理(比如发送给浏览器客户端). 我们当然可以先存到文件中, 然后再读进内存, 但是这样效率太低, 尤其需要读写硬盘. 既然pdfbox有输出到内存缓冲区的功能. 我们当然不能浪费.

当然为了看到效果, 下面的示例程序还是将图片保存到文件中.

``` java PDF2BufferedImage
private static final String BASE_PATH = "F:\\java\\";

public static void main(String[] args) throws IOException {
    File file = new File(BASE_PATH + "test.pdf");
    PDDocument doc = PDDocument.load(file);
    List<?> pages = doc.getDocumentCatalog().getAllPages();
    
    for (int i = 0; i < pages.size(); i++) {
        PDPage page = (PDPage) pages.get(i);   // 获取第i页
        BufferedImage image = page.convertToImage();
        
        // 输出到文件中
        String outPath = BASE_PATH + file.getName() + i + ".gif";
        try (FileOutputStream out = new FileOutputStream(outPath)) {
            ImageIO.write(image, "gif", out);
        }
    }
}
```

非常简单吧! 今天就说这么多吧. 需要源码的朋友可以从这里[下载][download code]源码.  如果各位朋友还有什么问题, 可以在下方的留言区留言, 我们相互讨论, 共同进步. 

[PDFRenderer]: https://java.net/projects/pdf-renderer/ "PDFRenderer主页"
[pdfbox]: http://pdfbox.apache.org/ "pdfbox主页"
[jpedal]: https://www.idrsolutions.com/jpedal/ "jpedal主页"
[ICEPDF]: http://www.icesoft.org/java/home.jsf "ICEPDF主页"
[download code]: /downloads/code/2016/04/pdf2image.zip "下载代码"
