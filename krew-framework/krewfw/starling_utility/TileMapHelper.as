package krewfw.starling_utility {

    import flash.geom.Point;
    import starling.display.Image;
    import starling.textures.Texture;

    /**
     * Tiled Map Editor (http://www.mapeditor.org/) $B$N(B tmx $B%U%!%$%k$+$i(B
     * $B=PNO$7$?(B json $B$r$b$H$K3F%^%9$N(B Image $B$rJV$9%f!<%F%#%j%F%#(B
     */
    //------------------------------------------------------------
    public class TileMapHelper {

        // avoid instantiation cost
        private static var _point:Point = new Point(0, 0);

        /**
         * Tiled Map Editor $B$G$O6u%?%$%k$O(B 0 $B$HI=8=$5$l$k!#(B
         * $B%=!<%9$N%?%$%k2hA|$N0lHV:8>e$O(B 1 $B$+$i;O$^$k!#(B
         * $B;XDj$7$?%^%9$,(B 0 $B$N>l9g$O(B null $B$rJV$9(B.
         *
         * [Note] $B0J2<$N%?%$%k2hA|$N%U%)!<%^%C%H$G%F%9%H!'(B
         * <pre>
         *     - Canvas size: 512 x 512
         *     - Tile size: 32 x 32
         *     - spacing: 2
         * </pre>
         */
        public static function getTileImage(tileMapInfo:Object, tileLayer:Object, tileSet:Object,
                                            tilesTexture:Texture, col:uint, row:uint):Image
        {
            // calculate UV coord
            var numMapCol:uint = tileLayer.width;
            var tileIndex:int  = tileLayer.data[(row * numMapCol) + col] - 1;
            if (tileIndex < 0) { return null; }

            // * consider spacing
            var tileWidth :Number = (tileSet.tilewidth  + tileSet.spacing);
            var tileHeight:Number = (tileSet.tileheight + tileSet.spacing);

            var numTileImageCol:uint = tileSet.imagewidth  / tileWidth;
            var numTileImageRow:uint = tileSet.imageheight / tileHeight;
            var tileImageCol:uint = tileIndex % numTileImageCol;
            var tileImageRow:uint = tileIndex / numTileImageCol;

            var uvLeft:Number = (tileWidth  * tileImageCol) / tileSet.imagewidth;
            var uvTop :Number = (tileHeight * tileImageRow) / tileSet.imageheight;
            var uvSize:Number = tileSet.tilewidth / tileSet.imagewidth;

            // make Image with UV
            var image:Image = new Image(tilesTexture);
            image.width  = tileMapInfo.tilewidth;
            image.height = tileMapInfo.tileheight;

            _point.setTo(uvLeft,          uvTop         );  image.setTexCoords(0, _point);
            _point.setTo(uvLeft + uvSize, uvTop         );  image.setTexCoords(1, _point);
            _point.setTo(uvLeft,          uvTop + uvSize);  image.setTexCoords(2, _point);
            _point.setTo(uvLeft + uvSize, uvTop + uvSize);  image.setTexCoords(3, _point);

            var padding:Number = 0.0005;  // $B$=$N$^$^(B UV $B;XDj$9$k$H%?%$%k4V$K$o$:$+$J7d4V$,8+$($F$7$^$C$?$N$G(B
            _setUv(image, 0, uvLeft         , uvTop         ,  padding,  padding);
            _setUv(image, 1, uvLeft + uvSize, uvTop         , -padding,  padding);
            _setUv(image, 2, uvLeft         , uvTop + uvSize,  padding, -padding);
            _setUv(image, 3, uvLeft + uvSize, uvTop + uvSize, -padding, -padding);

            return image;
        }

        /**
         * vertices index:
         *   0 - 1
         *   | / |
         *   2 - 3
         */
        private static function _setUv(image:Image, vertexId:int, x:Number, y:Number,
                                       paddingX:Number=0, paddingY:Number=0):void
        {
            _point.setTo(x + paddingX, y + paddingY);
            image.setTexCoords(vertexId, _point);
        }

    }
}
