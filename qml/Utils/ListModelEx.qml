import QtQuick 2.0

// Extended ListModel, with some useful functions to get items from the list

ListModel {
    id: listModelEx

    function getIndexFromProperty(modelProperty, propertyValue) {
        var i=0;
        for(i=0; i<this.count;i++) {
            var item=get(i);
            if(item && item[modelProperty] === propertyValue) {
                return i;
            }
        }

        console.log("ListModelEx " + objectName + ": couldn't find " + modelProperty + "!");
        return -1;
    }
}
