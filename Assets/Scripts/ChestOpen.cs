using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChestOpen : MonoBehaviour
{
    public Animator animator;
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void OnTriggerStay(Collider collider)
    {
        if (Input.GetKeyDown(KeyCode.E))
        {
            animator.SetTrigger("ChestOpen");
        }
    }
}