package krewfw.core {

    import flash.geom.Rectangle;
    import flash.utils.getQualifiedClassName;

    import starling.animation.Transitions;
    import starling.animation.Tween;
    import starling.display.DisplayObject;
    import starling.display.Image;
    import starling.display.Quad;
    import starling.text.TextField;
    import starling.textures.Texture;

    import krewfw.KrewConfig;
    import krewfw.builtin_actor.display.ColorRect;
    import krewfw.core_internal.KrewSharedObjects;
    import krewfw.core_internal.ProfileData;
    import krewfw.core_internal.StageLayer;
    import krewfw.core_internal.StuntAction;
    import krewfw.core_internal.StuntActionInstructor;
    import krewfw.utils.as3.KrewTimeKeeper;

    //------------------------------------------------------------
    public class KrewActor extends KrewGameObject {

        private var _hasInitialized:Boolean = false;
        private var _hasDisposed:Boolean    = false;
        private var _markedForDeath:Boolean = false;  // 死亡フラグ

        protected var _checkDisplayArea:Boolean = false;
        protected var _cachedWidth :Number;
        protected var _cachedHeight:Number;

        private var _initFuncList  :Vector.<Function>      = new Vector.<Function>();
        private var _imageList     :Vector.<Image>         = new Vector.<Image>();
        private var _displayObjList:Vector.<DisplayObject> = new Vector.<DisplayObject>();
        private var _textList      :Vector.<TextField>     = new Vector.<TextField>();
        private var _childActors   :Vector.<KrewActor>     = new Vector.<KrewActor>();

        private var _color:uint = 0xffffff;
        public  var applyForNewActor:Function;
        public  var layer:StageLayer;  // reference of layer this actor belonged to
        public  var layerName:String;

        private var _actionInstructors:Vector.<StuntActionInstructor> = new Vector.<StuntActionInstructor>();
        private var _timeKeeper:KrewTimeKeeper = new KrewTimeKeeper();

        /** high is front */
        public var displayOrder:int = 0;

        /**
         * addActor 前に false にすると addActor 時に addChild を行わない
         * (Starling の DisplayList にのせない.)
         * 見た目を持たずに仕事をする Actor はこれを false にすればよい
         */
        public var displayable:Boolean = true;

        /** false にすると CollisionShape が衝突判定を行わない */
        public var collidable:Boolean = true;

        /**
         * true にすると再セットアップが可能な状態に dispose する。
         * （GC を促すための null を入れることをしない）
         */
        public var poolable:Boolean = false;

        //------------------------------------------------------------
        // accessors
        //------------------------------------------------------------

        /**
         * [CAUTION] starling.display.DisplayObjectContainer の
         * width / height の getter は重い行列計算が走るので滅多なことでもない限り使うな
         */
        public function get cachedWidth():Number {
            return _cachedWidth;
        }

        /** @see cachedWidth */
        public function get cachedHeight():Number {
            return _cachedHeight;
        }

        public function get color():uint {
            return _color;
        }

        /** Actor が持つ Image や TextField 全てに色をセットする */
        public function set color(color:uint):void {
            _color = color;
            for each (var image:Image in _imageList) {
                image.color = color;
            }
            for each (var text:TextField in _textList) {
                text.color = color;
            }
        }

        public function get childActors():Vector.<KrewActor> {
            return _childActors;
        }

        public function get numActor():int {
            return _childActors.length;
        }

        public function get isDead():Boolean {
            return _markedForDeath;
        }

        public function get hasInitialized():Boolean {
            return _hasInitialized;
        }

        /** Called from StageLayerManager for re-init global actor. */
        public function set hasInitialized(value:Boolean):void {
            _hasInitialized = value;
        }

        //------------------------------------------------------------
        // constructors
        //------------------------------------------------------------

        public function KrewActor() {}

        /**
         * init が呼ばれる時（KrewScene.setUpActor に渡された時、または
         * Actor から addActor されたとき）に、init 後に呼ばれる関数を登録。
         * コンストラクタでの使用を想定.
         *
         * コンストラクタで引数を渡して init に用いたい場合、クラスメンバに値を
         * 保持しておくなどの手間がかかるため、それを楽にするためのもの。
         * 登録した関数は init 実行後に、登録した順番で呼ばれる。
         */
        public function addInitializer(initFunc:Function):void {
            _initFuncList.push(initFunc);
        }

        /** @private */
        public function setUp(sharedObj:KrewSharedObjects, applyForNewActor:Function,
                              layer:StageLayer, layerName:String):void
        {
            if (_hasInitialized) {
                if (!poolable) {
                    krew.fwlog('[Warning] KrewActor has initialized twice.');
                }
                return;
            }
            _hasInitialized = true;

            this.sharedObj        = sharedObj;
            this.applyForNewActor = applyForNewActor;
            this.layer            = layer;
            this.layerName        = layerName;

            _doInit();

            ProfileData.countActor(1, this.layerName);
        }

        private function _doInit():void {
            init();
            for each (var initFunc:Function in _initFuncList) {
                initFunc();
            }
        }

        //------------------------------------------------------------
        // destructors
        //------------------------------------------------------------

        /** @private */
        public override function dispose():void {
            if (_hasDisposed) { return; }
            _hasDisposed = true;

            if (poolable) {
                _disposeForReuse();
            } else {
                _disposeForGC();
            }
        }

        private function _disposeForGC():void {
            if (_hasInitialized) {
                _hasInitialized = false;
                ProfileData.countActor(-1, this.layerName);
            }

            for each (var child:KrewActor in _childActors) {
                child.dispose();
            }

            removeChildren(0, -1, true);
            removeCollision();
            _disposeImageTextures();
            _disposeTexts();
            _disposeDisplayObjs();
            _timeKeeper.dispose();
            react();

            _initFuncList      = null;
            _imageList         = null;
            _textList          = null;
            _displayObjList    = null;
            _childActors       = null;
            _actionInstructors = null;
            _timeKeeper        = null;
            layer              = null;

            onDispose();
            super.dispose();
        }

        private function _disposeForReuse():void {
            stopAllListening();
            _timeKeeper.dispose();
            react();

            onRecycle();
        }

        protected function _retrieveFromPool():void {
            _hasDisposed    = false;
            _markedForDeath = false;
        }

        protected function _disposeFromPool():void {
            _hasDisposed = false;
            poolable = false;
            dispose();
        }

        /** @private */
        protected function _disposeImageTextures():void {
            for (var i:uint=0;  i < _imageList.length;  ++i) {
                _imageList[i].dispose();
            }
        }

        /** @private */
        protected function _disposeTexts():void {
            for each (var text:TextField in _textList) {
                text.dispose();
            }
        }

        /** @private */
        protected function _disposeDisplayObjs():void {
            for each (var obj:DisplayObject in _displayObjList) {
                obj.dispose();
            }
        }

        /** @private */
        protected function removeCollision():void {
            if (!sharedObj) { return; }
            sharedObj.collisionSystem.removeShapeWithActor(this);
        }

        /**
         * poolable = true な Actor が dispose されるタイミングで、
         * onDispose の代わりに呼ばれる
         */
        protected function onRecycle():void {
            // Override in subclasses.
        }

        //------------------------------------------------------------
        // public interface
        //------------------------------------------------------------

        /**
         * addChild の代わりに addImage を呼ぶことで破棄時に Image.texture の dispose が
         * 呼ばれるようになる。また、KrewActor.color の指定で全 Image に色がかかるようになる
         */
        public function addImage(image:Image,
                                 width:Number=NaN, height:Number=NaN,
                                 x:Number=0, y:Number=0,
                                 anchorX:Number=0.5, anchorY:Number=0.5):void
        {
            image.x = x;
            image.y = y;
            if (!isNaN(width )) { image.width  = width;  }
            if (!isNaN(height)) { image.height = height; }

            // pivotX, Y は回転の軸だけでなく座標指定にも影響する
            // そして何故かソースの画像の解像度に対する座標で指定してやらないといけないようだ
            var textureRect:Rectangle = image.texture.frame;
            if (textureRect) {
                image.pivotX = textureRect.width  * anchorX;
                image.pivotY = textureRect.height * anchorY;
            } else {
                image.pivotX = image.texture.width  * anchorX;
                image.pivotY = image.texture.height * anchorY;
            }

            _cachedWidth  = width;
            _cachedHeight = height;

            super.addChild(image);
            _imageList.push(image);
        }

        public function changeImage(image:Image, imageName:String):void {
            var newTexture:Texture = sharedObj.resourceManager.getTexture(imageName);
            image.texture.dispose();
            image.texture = newTexture;
        }

        /**
         * Actor 全体の color に影響させたい場合は addChild ではなく addText で足す
         */
        public function addText(text:TextField, x:Number=NaN, y:Number=NaN):void {
            if (!isNaN(x)) { text.x = x; }
            if (!isNaN(y)) { text.y = y; }

            super.addChild(text);
            _textList.push(text);
        }

        /**
         * addChild したものは Actor 破棄時に勝手に dispose が呼ばれる
         */
        public override function addChild(child:DisplayObject):DisplayObject {
            super.addChild(child);
            _displayObjList.push(child);
            return child;
        }

        /**
         * krewFramework のシステムに Actor を登録し、同時に Starling の DisplayList に追加する.
         * 見た目を持たずに仕事をするような Actor は putOnDisplayList に false を渡すか、
         * Actor のコンストラクタで displayable に false を設定しておくと Starling の DisplayList
         * には追加しない
         */
        public function addActor(actor:KrewActor, putOnDisplayList:Boolean=true):void {
            _childActors.push(actor);
            if (putOnDisplayList  &&  actor.displayable) {
                addChild(actor);
            }

            if (actor.hasInitialized) { return; }
            actor.setUp(sharedObj, applyForNewActor, layer, layerName);
        }

        public function createActor(newActor:KrewActor, layerName:String=null):void {
            if (!newActor) {
                throw new Error("[Error] [KrewActor :: createActor] newActor is required.");
            }

            // layerName 省略時は自分と同じ layer に出す
            if (layerName == null) {
                layerName = this.layerName;
            }
            applyForNewActor(newActor, layerName);
        }

        public function passAway():void {
            _markedForDeath = true;
        }

        public function setVertexColor(color1:int=0, color2:int=0,
                                       color3:int=0, color4:int=0):void {
            for each (var image:Image in _imageList) {
                image.setVertexColor(0, color1);
                image.setVertexColor(1, color2);
                image.setVertexColor(2, color3);
                image.setVertexColor(3, color4);
            }
        }

        /**
         * for touch action adjustment.
         * [CAUTION] You should call this after actor's init (setUpActor or addActor).
         */
        public function addTouchMarginNode(touchWidth:Number=0, touchHeight:Number=0):void {
            var margin:Quad = new Quad(touchWidth, touchHeight);
            margin.alpha = 0;
            margin.x = -touchWidth  / 2;
            margin.y = -touchHeight / 2;
            addChild(margin);
        }

        /**
         * displayOrder の値でツリーをソート。 children が皆 KrewActor である前提。
         * actor.displayOrder = 1;  のように設定した上で
         * getLayer('hoge').sortDisplayOrder(); のように使う
         */
        public function sortDisplayOrder():void {
            sortChildren(function(a:KrewActor, b:KrewActor):int {
                if (a.displayOrder < b.displayOrder) { return -1; }
                if (a.displayOrder > b.displayOrder) { return  1; }
                return 0;
            });
        }

        //------------------------------------------------------------
        // Helpers for Tween
        //------------------------------------------------------------

        public function addTween(tween:Tween):void {
            if (!layer) {
                krew.fwlog('[Error] [KrewActor::addTween] This actor does not belong to any layer.');
                krew.fwlog('   - class: ' + getQualifiedClassName(this));
                return;
            }

            layer.juggler.add(tween);
        }

        public function removeTweens():void {
            if (!layer) {
                krew.fwlog('[Error] [KrewActor::removeTween] This actor does not belong to any layer.');
                krew.fwlog('   - class: ' + getQualifiedClassName(this));
                return;
            }

            layer.juggler.removeTweens(this);
        }

        public function enchant(duration:Number, transition:String=Transitions.LINEAR):Tween {
            if (!layer) {
                krew.fwlog('[Error] [KrewActor::enchant] This actor does not belong to any layer.');
                krew.fwlog('   - class: ' + getQualifiedClassName(this));
                return null;
            }

            // * juggler.tween use object pooling internally
            var tween:Tween = layer.juggler.tween(this, duration, {transition: transition}) as Tween;

            return tween;
        }

        //------------------------------------------------------------
        // Multi Tasker
        //------------------------------------------------------------

        public function act(action:StuntAction=null):StuntAction {
            var actionInstructor:StuntActionInstructor = new StuntActionInstructor(this, action);
            _actionInstructors.push(actionInstructor);
            return actionInstructor.action;
        }

        // purge actions
        public function react():void {
            for each (var actionInstructor:StuntActionInstructor in _actionInstructors) {
                actionInstructor.dispose();
            }

            _actionInstructors.length = 0;
            removeTweens();
        }

        private function _updateAction(passedTime:Number):void {
            for (var i:int=0;  i <_actionInstructors.length;  ++i) {
                var actionInstructor:StuntActionInstructor = _actionInstructors[i];
                actionInstructor.update(passedTime);

                if (actionInstructor.isAllActionFinished) {
                    actionInstructor.dispose();
                    _actionInstructors.splice(i, 1);  // remove instructor from Array
                    --i;
                }
            }
        }

        /** Equivalent to setTimeout(), but passed time will be based on game's timeline. */
        public function addScheduledTask(timeout:Number, task:Function):void {
            if (timeout <= 0) {
                task();
                return;
            }
            _timeKeeper.addPeriodicTask(timeout, task, 1);
        }

        /** Alias for addScheduledTask */
        public function delayed(timeout:Number, task:Function):void {
            addScheduledTask(timeout, task);
        }

        /** Equivalent to setInterval(), but passed time will be based on game's timeline. */
        public function addPeriodicTask(interval:Number, task:Function, times:int=-1):void {
            _timeKeeper.addPeriodicTask(interval, task, times);
        }

        /** Alias for addPeriodicTask */
        public function cyclic(interval:Number, task:Function, times:int=-1):void {
            addPeriodicTask(interval, task, times);
        }

        /** Runs task 1 times after n frames. */
        public function delayedFrame(task:Function, waitFrames:int=1):void {
            if (waitFrames <= 0) {
                task();
                return;
            }
            _timeKeeper.addPeriodicFrameTask(waitFrames, task, 1);
        }

        /** Runs task several times after n frames. */
        public function cyclicFrame(task:Function, waitFrames:int=1, times:int=-1):void {
            _timeKeeper.addPeriodicFrameTask(waitFrames, task, times);
        }

        //------------------------------------------------------------
        // Called by framework
        //------------------------------------------------------------

        /** @private */
        public final function update(passedTime:Number):void {
            if (_hasDisposed) { return; }

            // update children actors
            for (var i:int=0;  i < _childActors.length;  ++i) {
                var child:KrewActor = _childActors[i];
                if (child.isDead) {
                    _childActors.splice(i, 1);  // remove dead actor from Array
                    removeChild(child);
                    child.dispose();
                    --i;
                    continue;
                }
                child.update(passedTime);
            }

            onUpdate(passedTime);
            _timeKeeper.update(passedTime);
            _updateAction(passedTime);
            _disappearInOutside();
        }

        //------------------------------------------------------------
        /**
         * _checkDisplayArea = true の Actor は、画面外にいるときは表示を off にする。
         * これをやってあげないと少なくとも Flash では
         * 画面外でも普通に描画コストがかかってしまうようだ.
         *
         * いずれにせよ visible false でなければ Starling は描画のための
         * 計算とかをしだすので、それを避けるにはこれをやった方がいい
         *
         * つまるところ、数が多く画像のアンカーが中央にあるような Actor を
         * _checkDisplayArea = true にすればよい
         */
        private function _disappearInOutside():void {
            if (!_checkDisplayArea) { return; }

            // starling.display.DisplayObjectContainer の width / height は
            // getBounds という重い処理が走るのでうかつにさわってはいけない

            // オーバヘッドを抑えるため、ラフに計算。回転を考慮して大きめにとる。
            // 横長の画像などについては考えてないのでどうしようもないときは
            // _checkDisplayArea を false のままにしておくか、
            // _cachedWidth とかを書き換えるか、もしくは override してくれ

            var halfWidth :Number = (_cachedWidth  / 1.5) * scaleX;
            var halfHeight:Number = (_cachedHeight / 1.5) * scaleY;
            if (x + halfWidth  > 0  &&  x - halfWidth  < KrewConfig.SCREEN_WIDTH  &&
                y + halfHeight > 0  &&  y - halfHeight < KrewConfig.SCREEN_HEIGHT) {
                visible = true;
            } else {
                visible = false;
            }
        }
    }
}
